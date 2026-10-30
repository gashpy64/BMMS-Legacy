using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;
using HtmlAgilityPack;

namespace BMMSBAL
{
    /// <summary>
    /// Rich text (FreeTextBox) cleaned to a fixed allow-list before it is saved or shown (step A1a).
    /// Kept: p, br, b, strong, i, em, u, ul, ol, li, table, thead, tbody, tr, th, td; align (left, right,
    /// center, justify) on p, td and th, also taken from style="text-align:..."; colspan and rowspan 1 to 100
    /// on td and th. Every table is written with border="1" cellpadding="4" cellspacing="0".
    /// div becomes p, h1 to h6 a bold paragraph, tfoot tbody. Script, style, frames, objects, images, form
    /// fields and comments are removed with their content; any other tag (a, span, font, o:p, code ...) is
    /// removed and its text kept. Every other attribute is removed. The text is written with &amp; &lt; &gt;
    /// and &nbsp; only, every other character (rupee sign, Tamil, Hindi) as itself.
    /// The output is written here, never taken from HtmlAgilityPack, and cleaning it again gives the same
    /// text. Clean never throws: input it cannot read comes back as encoded plain text.
    /// </summary>
    public static class HtmlCleaner
    {
        // Deeper than this, tags are left out and only the text is kept (no deep recursion anywhere)
        private const int MaxDepth = 200;

        private const string TableStart = "<table border=\"1\" cellpadding=\"4\" cellspacing=\"0\">";

        private static readonly HashSet<string> Allowed = new HashSet<string>(StringComparer.Ordinal)
        {
            "p", "br", "b", "strong", "i", "em", "u", "ul", "ol", "li",
            "table", "thead", "tbody", "tr", "th", "td"
        };

        // Removed together with everything inside
        private static readonly HashSet<string> RemovedWithContent = new HashSet<string>(StringComparer.Ordinal)
        {
            "script", "style", "iframe", "frame", "frameset", "object", "embed", "applet", "param",
            "noscript", "template", "svg", "math", "head", "title", "meta", "link", "base", "xml",
            "input", "select", "option", "optgroup", "textarea", "button", "img", "picture", "source",
            "audio", "video", "track", "canvas", "map", "area", "caption", "col", "colgroup"
        };

        // Removed when nothing is left inside
        private static readonly HashSet<string> RemoveWhenEmpty = new HashSet<string>(StringComparer.Ordinal)
        {
            "b", "strong", "i", "em", "u", "li", "ul", "ol", "table", "thead", "tbody", "tr"
        };

        // A p (or div, h1 to h6) with one of these inside is not written: nested blocks are not kept in a p
        private static readonly HashSet<string> Block = new HashSet<string>(StringComparer.Ordinal)
        {
            "p", "div", "ul", "ol", "table", "h1", "h2", "h3", "h4", "h5", "h6", "blockquote",
            "pre", "section", "article", "header", "footer", "aside", "nav", "dl", "form", "fieldset",
            "address", "center", "hr", "tfoot", "thead", "tbody", "tr", "td", "th", "li"
        };

        private static readonly HashSet<string> AlignValues = new HashSet<string>(StringComparer.Ordinal)
        {
            "left", "right", "center", "justify"
        };

        private static readonly Regex TextAlign = new Regex(@"text-align\s*:\s*([a-zA-Z]+)", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

        #region Clean
        public static string Clean(string html)
        {
            if (string.IsNullOrEmpty(html))
                return string.Empty;

            try
            {
                HtmlDocument doc = new HtmlDocument();
                doc.LoadHtml(html);

                return new Writer().Write(doc.DocumentNode);
            }
            catch (Exception)
            {
                // The only catch: input that cannot be read is kept as plain text
                return EncodeText(html);
            }
        }
        #endregion

        #region EncodeText
        // & < > as entities, U+00A0 as &nbsp;, control characters other than tab and line breaks left out
        private static string EncodeText(string text)
        {
            StringBuilder sb = new StringBuilder(text.Length + 16);
            foreach (char c in text)
            {
                switch (c)
                {
                    case '&': sb.Append("&amp;"); break;
                    case '<': sb.Append("&lt;"); break;
                    case '>': sb.Append("&gt;"); break;
                    case ' ': sb.Append("&nbsp;"); break;
                    default:
                        if (c >= ' ' || c == '\t' || c == '\n' || c == '\r')
                            sb.Append(c);
                        break;
                }
            }
            return sb.ToString();
        }
        #endregion

        #region Writer
        private sealed class Writer
        {
            // One step of the walk: a node to write, or the end tag of an element already started
            private sealed class Step
            {
                public HtmlNode Node;
                public int Depth;

                public bool IsEnd;
                public string Tag;          // the tag written (p for div)
                public bool BoldParagraph;  // h1 to h6: <p><strong>
                public int StartPos;        // where the start tag begins in the output
                public int ContentPos;      // where the content begins
            }

            private readonly StringBuilder sb = new StringBuilder();
            private readonly List<string> open = new List<string>();
            private bool lastWasEmptyParagraph;

            public string Write(HtmlNode root)
            {
                Stack<Step> steps = new Stack<Step>();
                PushChildren(steps, root, 0);

                while (steps.Count > 0)
                {
                    Step step = steps.Pop();
                    if (step.IsEnd)
                        End(step);
                    else
                        Visit(steps, step.Node, step.Depth);
                }

                return sb.ToString();
            }

            private static void PushChildren(Stack<Step> steps, HtmlNode node, int depth)
            {
                HtmlNodeCollection children = node.ChildNodes;
                for (int i = children.Count - 1; i >= 0; i--)
                    steps.Push(new Step { Node = children[i], Depth = depth });
            }

            private void Visit(Stack<Step> steps, HtmlNode node, int depth)
            {
                if (node.NodeType == HtmlNodeType.Text)
                {
                    string text = HtmlEntity.DeEntitize(((HtmlTextNode)node).Text);
                    if (!IsBlank(text))
                        lastWasEmptyParagraph = false;
                    sb.Append(EncodeText(text));
                    return;
                }

                if (node.NodeType == HtmlNodeType.Document)
                {
                    PushChildren(steps, node, depth);
                    return;
                }

                if (node.NodeType != HtmlNodeType.Element)
                    return;     // comments, including Word's <!--[if ...]>

                string name = node.Name.ToLowerInvariant();

                if (RemovedWithContent.Contains(name))
                    return;

                if (depth >= MaxDepth)
                {
                    PushChildren(steps, node, depth + 1);
                    return;
                }

                if (name == "br")
                {
                    sb.Append("<br />");
                    lastWasEmptyParagraph = false;
                    return;
                }

                string tag = name;
                bool boldParagraph = false;

                if (name == "div")
                    tag = "p";
                else if (name.Length == 2 && name[0] == 'h' && name[1] >= '1' && name[1] <= '6')
                {
                    tag = "p";
                    boldParagraph = true;
                }
                else if (name == "tfoot")
                    tag = "tbody";

                if (!Allowed.Contains(tag) || !FitsHere(tag, node))
                {
                    // Tag left out, content kept
                    PushChildren(steps, node, depth + 1);
                    return;
                }

                Step end = new Step { IsEnd = true, Tag = tag, BoldParagraph = boldParagraph, StartPos = sb.Length };

                if (tag == "table")
                    sb.Append(TableStart);
                else
                {
                    sb.Append('<').Append(tag);
                    if (tag == "p" || tag == "td" || tag == "th")
                    {
                        string align = Align(node);
                        if (align != null)
                            sb.Append(" align=\"").Append(align).Append('"');
                    }
                    if (tag == "td" || tag == "th")
                    {
                        AppendSpan(node, "colspan");
                        AppendSpan(node, "rowspan");
                    }
                    sb.Append('>');
                }
                if (boldParagraph)
                    sb.Append("<strong>");

                end.ContentPos = sb.Length;
                open.Add(tag);

                steps.Push(end);
                PushChildren(steps, node, depth + 1);
            }

            private void End(Step step)
            {
                open.RemoveAt(open.Count - 1);

                if (step.Tag == "p")
                {
                    string content = sb.ToString(step.ContentPos, sb.Length - step.ContentPos);
                    if (IsBlankHtml(content))
                    {
                        // An empty paragraph keeps its line; several in a row become one
                        sb.Length = step.StartPos;
                        if (!lastWasEmptyParagraph)
                        {
                            sb.Append("<p>&nbsp;</p>");
                            lastWasEmptyParagraph = true;
                        }
                        return;
                    }

                    if (step.BoldParagraph)
                        sb.Append("</strong>");
                    sb.Append("</p>");
                    lastWasEmptyParagraph = false;
                    return;
                }

                if (RemoveWhenEmpty.Contains(step.Tag) && IsBlankHtml(sb.ToString(step.ContentPos, sb.Length - step.ContentPos)))
                {
                    sb.Length = step.StartPos;
                    return;
                }

                sb.Append("</").Append(step.Tag).Append('>');
                lastWasEmptyParagraph = false;
            }

            // Where a tag may be written: no p inside a p or around a block, table parts only in a table,
            // list items only in a list
            private bool FitsHere(string tag, HtmlNode node)
            {
                switch (tag)
                {
                    case "p":
                        return !open.Contains("p") && !HasBlockInside(node);
                    case "li":
                        string list = Innermost("ul", "ol", "table");
                        return list == "ul" || list == "ol";
                    case "thead":
                    case "tbody":
                        return open.Count > 0 && open[open.Count - 1] == "table";
                    case "tr":
                        return open.Count > 0 && (open[open.Count - 1] == "table" || open[open.Count - 1] == "thead" || open[open.Count - 1] == "tbody");
                    case "td":
                    case "th":
                        return open.Count > 0 && open[open.Count - 1] == "tr";
                    default:
                        return true;
                }
            }

            // The innermost of the given tags that is open, or null
            private string Innermost(params string[] tags)
            {
                for (int i = open.Count - 1; i >= 0; i--)
                    if (Array.IndexOf(tags, open[i]) >= 0)
                        return open[i];
                return null;
            }

            // A block element anywhere inside (walked without recursion)
            private static bool HasBlockInside(HtmlNode node)
            {
                Stack<HtmlNode> pending = new Stack<HtmlNode>();
                foreach (HtmlNode child in node.ChildNodes)
                    pending.Push(child);

                while (pending.Count > 0)
                {
                    HtmlNode n = pending.Pop();
                    if (n.NodeType != HtmlNodeType.Element)
                        continue;

                    string name = n.Name.ToLowerInvariant();
                    if (RemovedWithContent.Contains(name))
                        continue;
                    if (Block.Contains(name))
                        return true;

                    foreach (HtmlNode child in n.ChildNodes)
                        pending.Push(child);
                }
                return false;
            }

            private static string Align(HtmlNode node)
            {
                string style = node.GetAttributeValue("style", string.Empty);
                Match m = TextAlign.Match(HtmlEntity.DeEntitize(style));
                string value = m.Success ? m.Groups[1].Value : node.GetAttributeValue("align", string.Empty);

                value = value.Trim().ToLowerInvariant();
                return AlignValues.Contains(value) ? value : null;
            }

            private void AppendSpan(HtmlNode node, string attribute)
            {
                int span;
                string value = node.GetAttributeValue(attribute, string.Empty).Trim();
                if (int.TryParse(value, System.Globalization.NumberStyles.None, System.Globalization.CultureInfo.InvariantCulture, out span)
                    && span >= 1 && span <= 100)
                    sb.Append(' ').Append(attribute).Append("=\"").Append(span).Append('"');
            }

            // Text that is only spaces, line breaks and no-break spaces
            private static bool IsBlank(string text)
            {
                foreach (char c in text)
                    if (!char.IsWhiteSpace(c) && c != ' ')
                        return false;
                return true;
            }

            // Written HTML with no tag and only blank text (&nbsp; counts as blank)
            private static bool IsBlankHtml(string html)
            {
                if (html.IndexOf('<') >= 0)
                    return false;
                return IsBlank(html.Replace("&nbsp;", " "));
            }
        }
        #endregion
    }
}
