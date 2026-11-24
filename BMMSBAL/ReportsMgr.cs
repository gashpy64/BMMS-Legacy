using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{

    #region ReportsMgr
    public class ReportsMgr
    {
        #region Every-status reports (step RA1b, BMMS-Fix-ReportAccess-Step41.sql)
        // The Controller's and Management's Minutes report in every minutes status, and Management's Followup.
        // Each call passes the acting user; the procedure checks the role in the database (Reason 8: missing or
        // inactive; Reason 4: another role; then no rows). Reason comes back 0 when allowed.
        public const string NoMeetingsWithMinutesMessage = "No meetings with minutes for this committee.";

        public static string ReportRefusedMessage(int Reason)
        {
            if (Reason == 8)
                return "Your session is no longer valid. Please log in again.";
            return "You are not allowed to see this report.";
        }

        public static DataTable GetMinutesReportMeetingsAllStatus(int CommitteeId, int ActingUserId, out int Reason)
        {
            return MinutesDB.GetMinutesReportMeetingsAllStatus(CommitteeId, ActingUserId, out Reason);
        }

        public static DataTable GetMinutesReportAllStatus(int CommitteeId, int DepartmentId, int MeetingNoSearch, int MeetingId, int FromMeetingId, int ToMeetingId,
            int SubjectNoSearch, int FromSubjectNo, int ToSubjectNo, int ActingUserId, out int Reason)
        {
            return MinutesDB.GetMinutesReportAllStatus(CommitteeId, DepartmentId, MeetingNoSearch, MeetingId, FromMeetingId, ToMeetingId,
                SubjectNoSearch, FromSubjectNo, ToSubjectNo, ActingUserId, out Reason);
        }

        // The mark of a report row; "" when the row has no MinutesStatusMark (the Controller's Followup, whose rows
        // carry it as NULL since step 49, the finalised-only reports)
        public static string StatusMarkOf(DataRow Row)
        {
            if (Row == null || !Row.Table.Columns.Contains("MinutesStatusMark") || Row["MinutesStatusMark"] == DBNull.Value)
                return string.Empty;
            return Row["MinutesStatusMark"].ToString();
        }
        #endregion


        #region GetFollowupReport
        // Step FU2b (BMMS-Fix-FollowupReports-Step49.sql): Followup and Followup Summary for the Controller and
        // Management, through spr_GetFollowupReport with the acting user (the role is read in the database: Reason 8
        // missing, inactive or the system account; Reason 4 another role; then no rows). The same rows, filters and
        // order as the query built here before (and spr_GetFollowupReportForManagement for Management), with AgendaNo,
        // ActionItemId for rows the old order left to the server, and the status columns of the latest history row.
        // The From and To meeting dates of the page are not used, as before.
        public static DataTable GetFollowupReport(int ActingUserId, int CommitteeId, int MeetingNoSearch, int MeetingId, int FromMeetingId,
            int ToMeetingId, int DepartmentId, int ConfirmStatus, out int Reason)
        {
            return ActionItemDB.GetFollowupReport(ActingUserId, CommitteeId, MeetingNoSearch, MeetingId, FromMeetingId, ToMeetingId,
                DepartmentId, ConfirmStatus, out Reason);
        }
        #endregion


        #region Agenda and minutes reports by the acting user (step UD1c, BMMS-Fix-ManagerScope-Step54.sql)
        // Agenda Summary, Agenda Details, Minutes and Minutes Extract read procedures with the acting user; no SQL text is
        // built here any more. The procedure reads the role and, for a Manager, his departments (fn_ManagerDepartments) in
        // the database: the Controller every department, a Manager his departments only (DepartmentId 0 or less = all of
        // them; another department is refused). Reason 0 when allowed; 8 (acting user missing or inactive) or 4 (another
        // role, or a department that is not his), then no rows: ReportRefusedMessage gives the page's text.
        // Agenda Summary of one meeting and Agenda Details: committee, meeting, subject number (OrderBy 1).
        public static DataTable GetAgendaSummaryReport(int ActingUserId, int CommitteeId, int DepartmentId, int MeetingNoSearch, int MeetingId,
            int FromMeetingId, int ToMeetingId, int SubjectNoSearch, int FromSubjectNo, int ToSubjectNo, out int Reason)
        {
            return AgendaDB.GetAgendaReport(ActingUserId, CommitteeId, DepartmentId, MeetingNoSearch, MeetingId, FromMeetingId, ToMeetingId,
                SubjectNoSearch, FromSubjectNo, ToSubjectNo, 1, out Reason);
        }

        // Agenda Summary of every meeting or of a range: department, meeting, subject number (OrderBy 2)
        public static DataTable GetAgendaSummaryFullReport(int ActingUserId, int CommitteeId, int DepartmentId, int MeetingNoSearch, int MeetingId,
            int FromMeetingId, int ToMeetingId, int SubjectNoSearch, int FromSubjectNo, int ToSubjectNo, out int Reason)
        {
            return AgendaDB.GetAgendaReport(ActingUserId, CommitteeId, DepartmentId, MeetingNoSearch, MeetingId, FromMeetingId, ToMeetingId,
                SubjectNoSearch, FromSubjectNo, ToSubjectNo, 2, out Reason);
        }

        public static DataTable GetAgendaDetailsReport(int ActingUserId, int CommitteeId, int DepartmentId, int MeetingNoSearch, int MeetingId,
            int FromMeetingId, int ToMeetingId, int SubjectNoSearch, int FromSubjectNo, int ToSubjectNo, out int Reason)
        {
            return AgendaDB.GetAgendaReport(ActingUserId, CommitteeId, DepartmentId, MeetingNoSearch, MeetingId, FromMeetingId, ToMeetingId,
                SubjectNoSearch, FromSubjectNo, ToSubjectNo, 1, out Reason);
        }

        // Minutes and Minutes Extract: only meetings with finalized or confirmed minutes (step 22); the extract reads the same rows
        public static DataTable GetMinutesReport(int ActingUserId, int CommitteeId, int DepartmentId, int MeetingNoSearch, int MeetingId,
            int FromMeetingId, int ToMeetingId, int SubjectNoSearch, int FromSubjectNo, int ToSubjectNo, out int Reason)
        {
            return MinutesDB.GetMinutesReportByUser(ActingUserId, CommitteeId, DepartmentId, MeetingNoSearch, MeetingId, FromMeetingId, ToMeetingId,
                SubjectNoSearch, FromSubjectNo, ToSubjectNo, out Reason);
        }

        public static DataTable GetMinutesExtractReport(int ActingUserId, int CommitteeId, int DepartmentId, int MeetingNoSearch, int MeetingId,
            int FromMeetingId, int ToMeetingId, int SubjectNoSearch, int FromSubjectNo, int ToSubjectNo, out int Reason)
        {
            return MinutesDB.GetMinutesReportByUser(ActingUserId, CommitteeId, DepartmentId, MeetingNoSearch, MeetingId, FromMeetingId, ToMeetingId,
                SubjectNoSearch, FromSubjectNo, ToSubjectNo, out Reason);
        }

        // The From / To subject number lists of a meeting (DepartmentId -1 = every department of the acting user's scope)
        public static DataTable GetReportSubjectNos(int ActingUserId, int MeetingId, int DepartmentId, out int Reason)
        {
            return MinutesDB.GetReportSubjectNos(ActingUserId, MeetingId, DepartmentId, out Reason);
        }
        #endregion
    }
    #endregion

}
