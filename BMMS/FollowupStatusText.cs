using System;
using System.Globalization;
using BMMSBAL;

namespace BMMS
{
    /// <summary>
    /// Step FU2a (step 48): the texts of a followup's status, from the latest row of Action_Item_Status_History
    /// (step 47), in one place for the two pages that show them: the Status cell of Master/Followup.aspx and the
    /// status line under the action text of the Dashboard's Action Item Details panel.
    ///
    ///   Confirmed by Name (login) on dd-MMM-yyyy HH:mm
    ///   Reopened by Name (login) on dd-MMM-yyyy HH:mm: reason
    ///   Confirmed (before history)          confirmed, no history row (confirmed before step 47)
    ///   Confirmed                           confirmed, but the latest row is not a Confirm
    ///
    /// The name is "Name (login)" (Common.UserDisplayName, step UN3) with " (inactive)" for an inactive account,
    /// "an unknown user" when there is none; the time is the database server's (ActedOn = GETDATE()), "an unknown
    /// date" when there is none. Every text is PLAIN TEXT: the page encodes it (HttpUtility.HtmlEncode, or
    /// InnerText).
    /// </summary>
    public static class FollowupStatusText
    {
        public const string DateTimeFormat = "dd-MMM-yyyy HH:mm";
        public const string ConfirmedWord = "Confirmed";
        public const string ConfirmedBeforeHistory = "Confirmed (before history)";

        /// <summary>A flag as everywhere IsConfirmed is read (ISNULL(x, 0) &lt;&gt; 0); NULL and blank are 0.</summary>
        public static bool IsSet(object value)
        {
            if (value == null || value == DBNull.Value)
                return false;
            int n;
            return int.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), out n) && n != 0;
        }

        /// <summary>"Name (login)" of the user who acted, " (inactive)" added; "an unknown user" when none.</summary>
        public static string ActedByName(object name, object login, object active)
        {
            string text = Common.UserDisplayName(Convert.ToString(name), Convert.ToString(login), IsSet(active));
            return text.Length > 0 ? text : "an unknown user";
        }

        /// <summary>The time of the history row, dd-MMM-yyyy HH:mm; "an unknown date" when none.</summary>
        public static string ActedOnText(object on)
        {
            if (on == null || on == DBNull.Value)
                return "an unknown date";
            return Convert.ToDateTime(on).ToString(DateTimeFormat, CultureInfo.InvariantCulture);
        }

        /// <summary>"Confirmed by Name (login) on dd-MMM-yyyy HH:mm"</summary>
        public static string ConfirmedLine(object name, object login, object active, object on)
        {
            return "Confirmed by " + ActedByName(name, login, active) + " on " + ActedOnText(on);
        }

        /// <summary>"Reopened by Name (login) on dd-MMM-yyyy HH:mm: reason"</summary>
        public static string ReopenedLine(object name, object login, object active, object on, object reason)
        {
            return "Reopened by " + ActedByName(name, login, active) + " on " + ActedOnText(on) + ": " + Convert.ToString(reason);
        }

        /// <summary>
        /// The one status line of an item (the Dashboard's panel): for a confirmed item the Confirm line, "Confirmed
        /// (before history)" or "Confirmed"; for an item that is not confirmed the Reopen line when its latest row is
        /// a Reopen, else empty (no line).
        /// </summary>
        public static string Caption(bool confirmed, object action, object reason, object on, object name, object login, object active)
        {
            string act = Convert.ToString(action);
            if (confirmed)
            {
                if (act == "Confirm")
                    return ConfirmedLine(name, login, active, on);
                if (act.Length == 0)
                    return ConfirmedBeforeHistory;
                return ConfirmedWord;
            }
            if (act == "Reopen")
                return ReopenedLine(name, login, active, on, reason);
            return string.Empty;
        }
    }
}
