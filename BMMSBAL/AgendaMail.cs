using System;
using System.Data;
using System.Web;

namespace BMMSBAL
{
    /// <summary>
    /// Step ML2b: the parts of the agenda mails (Created, Updated, approved, rejected, rejected on agenda finalized)
    /// that every one of them shares, so the pages no longer each build their own copy.
    /// </summary>
    public static class AgendaMail
    {
        #region DetailRows
        /// <summary>
        /// The detail rows of an agenda mail, without the table tags: Agenda No, Subject No (only when it has a
        /// value), Committee Name, Meeting No, Meeting Date (dd-MMM-yyyy), Department, Subject Type, then Short Text.
        /// Every value is HTML-encoded. The layout is the one the pages built before step ML2b.
        /// </summary>
        public static string DetailRows(string AgendaNo, string SubjectNo, string CommitteeName, string MeetingNo,
            object MeetingDate, string Department, string SubjectType, string ShortText)
        {
            bool hasSubjectNo = Trimmed(SubjectNo) != string.Empty;

            string BodyText = string.Empty;

            BodyText += "<tr>";
            BodyText += "<td style='text-align:left; font-weight:bold; width:150px;'>";
            BodyText += "Agenda No <br /><br />";
            if (hasSubjectNo)
                BodyText += "Subject No <br /><br />";
            BodyText += "Committee Name <br /><br />";
            BodyText += "Meeting No <br /><br />";
            BodyText += "Meeting Date <br /><br />";
            BodyText += "Department <br /><br />";
            BodyText += "Subject Type <br /><br />";
            BodyText += "</td>";

            BodyText += "<td style='text-align:left; font-weight:normal;'>";
            BodyText += ": " + HttpUtility.HtmlEncode(Trimmed(AgendaNo)) + "<br /><br />";
            if (hasSubjectNo)
                BodyText += ": " + HttpUtility.HtmlEncode(Trimmed(SubjectNo)) + "<br /><br />";
            BodyText += ": " + HttpUtility.HtmlEncode(Trimmed(CommitteeName)) + "<br /><br />";
            BodyText += ": " + HttpUtility.HtmlEncode(Trimmed(MeetingNo)) + "<br /><br />";
            BodyText += ": " + HttpUtility.HtmlEncode(FormatMeetingDate(MeetingDate)) + "<br /><br />";
            BodyText += ": " + HttpUtility.HtmlEncode(Trimmed(Department)) + "<br /><br />";
            BodyText += ": " + HttpUtility.HtmlEncode(Trimmed(SubjectType)) + "<br /><br />";
            BodyText += "</td>";

            BodyText += "</tr>";

            BodyText += "<tr>";
            BodyText += "<td style='text-align:left; font-weight:bold; width:150px;'>";
            BodyText += "Short Text <br /><br />";
            BodyText += "</td>";

            BodyText += "<td style='text-align:left; font-weight:normal;'>";
            BodyText += ": " + HttpUtility.HtmlEncode(Trimmed(ShortText)) + "<br /><br />";
            BodyText += "</td>";

            BodyText += "</tr>";

            return BodyText;
        }

        /// <summary>The detail rows from a View_Agenda row (spr_GetAgendaByAgendaId).</summary>
        public static string DetailRows(DataRow Item)
        {
            return DetailRows(Item["AgendaNo"].ToString(), Item["SubjectNo"].ToString(), Item["CommitteeName"].ToString(),
                Item["MeetingNo"].ToString(), Item["MeetingDate"], Item["DepartmentName"].ToString(),
                Item["SubjectTypeName"].ToString(), Item["ShortText"].ToString());
        }
        #endregion

        #region FormatMeetingDate
        // dd-MMM-yyyy, as the pages' FormatDate (current culture both ways); a NULL, empty or unreadable date is empty
        public static string FormatMeetingDate(object value)
        {
            DateTime date;
            if (value == null || value == DBNull.Value)
                return string.Empty;
            if (value is DateTime)
                return ((DateTime)value).ToString("dd-MMM-yyyy");
            if (!DateTime.TryParse(value.ToString(), out date))
                return string.Empty;
            return date.ToString("dd-MMM-yyyy");
        }
        #endregion

        #region CommentRow
        /// <summary>
        /// One row with the comment, laid out as the detail rows: the label ("Manager's comment" or "Controller's
        /// comment") in bold in the label cell; in the value cell, after ": ", a smaller grey line with who and when
        /// ("Name, dd-MMM-yyyy HH:mm", AgendaMgr.CommentAuthor; no line when there is none), then the comment cleaned
        /// to the rich-text allow-list (HtmlCleaner, as on Send Mail: no script, no event handlers, no style), with
        /// leading and trailing spaces and &amp;nbsp; removed. Empty when the comment shows no text.
        /// </summary>
        public static string CommentRow(string Label, object Comment, object ById, object On)
        {
            string html = Comment == null || Comment == DBNull.Value ? string.Empty : HtmlCleaner.Clean(Comment.ToString());
            if (HtmlCleaner.IsBlank(html))
                return string.Empty;

            html = TrimHtml(html);
            string author = AgendaMgr.CommentAuthor(ById, On);

            string BodyText = string.Empty;
            BodyText += "<tr>";
            BodyText += "<td style='text-align:left; font-weight:bold; width:150px; vertical-align:top;'>";
            BodyText += HttpUtility.HtmlEncode(Label) + " <br /><br />";
            BodyText += "</td>";

            BodyText += "<td style='text-align:left; font-weight:normal;'>";
            BodyText += ": ";
            if (author.Length > 0)
                BodyText += "<span style='font-size:smaller; color:#666666;'>" + HttpUtility.HtmlEncode(author) + "</span><br />";
            BodyText += html;
            BodyText += "<br /><br />";
            BodyText += "</td>";
            BodyText += "</tr>";
            return BodyText;
        }

        // Leading and trailing white space and &nbsp; of cleaned HTML, also inside the opening and closing tags at
        // either end ("<p> text&nbsp;</p>" becomes "<p>text</p>"); the tags themselves are kept. One pass from each
        // end, linear in the length (a regular expression here backtracked for minutes on a long run of spaces).
        private static string TrimHtml(string html)
        {
            System.Text.StringBuilder head = new System.Text.StringBuilder();
            int start = 0;
            while (start < html.Length)
            {
                char c = html[start];
                if (c == '<')
                {
                    int close = html.IndexOf('>', start);
                    if (close < 0)
                        break;
                    head.Append(html, start, close - start + 1);   // a tag before the first text: kept
                    start = close + 1;
                }
                else if (char.IsWhiteSpace(c))
                    start++;
                else if (IsSpaceEntityAt(html, start))
                    start += 6;
                else
                    break;
            }

            System.Collections.Generic.List<string> tail = new System.Collections.Generic.List<string>();
            int end = html.Length;   // exclusive
            while (end > start)
            {
                char c = html[end - 1];
                if (c == '>')
                {
                    int open = html.LastIndexOf('<', end - 1, end - start);
                    if (open < 0)
                        break;
                    tail.Add(html.Substring(open, end - open));   // a tag after the last text: kept
                    end = open;
                }
                else if (char.IsWhiteSpace(c))
                    end--;
                else if (end - 6 >= start && IsSpaceEntityAt(html, end - 6))
                    end -= 6;
                else
                    break;
            }

            System.Text.StringBuilder result = head;
            result.Append(html, start, end - start);
            for (int k = tail.Count - 1; k >= 0; k--)
                result.Append(tail[k]);
            return result.ToString();
        }

        private static bool IsSpaceEntityAt(string html, int index)
        {
            return string.CompareOrdinal(html, index, "&nbsp;", 0, 6) == 0 || string.CompareOrdinal(html, index, "&#160;", 0, 6) == 0;
        }

        /// <summary>
        /// The comment row of an approve or reject mail. RoleCode "manager" uses the Manager's comment, "controller"
        /// the Controller's. After is the item read after the save. A comment the decision changed (or a new one)
        /// shows who decided and when (step 35 writes them with the decision); a comment the decision did not change
        /// shows the who and when of Before, the item read before the save, or the label alone when Before has none
        /// or is missing. Compared exactly (case and trailing spaces count; NULL and empty are the same), as in steps
        /// 35 and 36.
        /// </summary>
        public static string DecisionCommentRow(string RoleCode, DataRow Before, DataRow After)
        {
            string label, textColumn, byColumn, dateColumn;
            if (RoleCode == "manager")
            {
                label = AgendaMgr.ManagerCommentLabel;
                textColumn = "MgrComments"; byColumn = "MgrApprovedBy"; dateColumn = "MgrApprovedDate";
            }
            else if (RoleCode == "controller")
            {
                label = AgendaMgr.ControllerCommentLabel;
                textColumn = "ControllerComments"; byColumn = "ControllerApprovedBy"; dateColumn = "ControllerApprovedDate";
            }
            else
                return string.Empty;

            if (After == null)
                return string.Empty;

            object comment = After[textColumn];
            if (Before == null)
                return CommentRow(label, comment, null, null);

            if (SameText(Before[textColumn], comment))
                return CommentRow(label, comment, Before[byColumn], Before[dateColumn]);

            return CommentRow(label, comment, After[byColumn], After[dateColumn]);
        }
        #endregion

        #region helpers
        private static bool SameText(object A, object B)
        {
            string a = A == null || A == DBNull.Value ? string.Empty : A.ToString();
            string b = B == null || B == DBNull.Value ? string.Empty : B.ToString();
            return string.Equals(a, b, StringComparison.Ordinal);
        }

        private static string Trimmed(string value)
        {
            return value == null ? string.Empty : value.Trim();
        }
        #endregion
    }
}
