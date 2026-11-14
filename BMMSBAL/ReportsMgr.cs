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

        public static DataTable GetFollowupReportForManagement(int CommitteeId, int MeetingNoSearch, int MeetingId, int FromMeetingId,
            int ToMeetingId, int DepartmentId, int ConfirmStatus, int ActingUserId, out int Reason)
        {
            return ActionItemDB.GetFollowupReportForManagement(CommitteeId, MeetingNoSearch, MeetingId, FromMeetingId,
                ToMeetingId, DepartmentId, ConfirmStatus, ActingUserId, out Reason);
        }

        // The mark of a report row; "" when the row has no MinutesStatusMark (the Controller's Followup, the
        // finalised-only reports)
        public static string StatusMarkOf(DataRow Row)
        {
            if (Row == null || !Row.Table.Columns.Contains("MinutesStatusMark") || Row["MinutesStatusMark"] == DBNull.Value)
                return string.Empty;
            return Row["MinutesStatusMark"].ToString();
        }
        #endregion


        #region GetFollowupReport
        public static DataTable GetFollowupReport(DateTime FromMeetingDate, DateTime ToMeetingDate, int CommitteeId,
            int MeetingNoSearch, int MeetingId, int FromMeetingId, int ToMeetingId, int DepartmentId, int ConfirmStatus)
        {
            string SQL_Query_Text = string.Empty;

            SQL_Query_Text += "SELECT * FROM View_Action_Item WHERE 1=1";

            if (CommitteeId > 0)
            {
                SQL_Query_Text += " AND CommitteeId = " + CommitteeId;

                if (MeetingNoSearch == 0)
                    if (MeetingId > 0)
                        SQL_Query_Text += " AND MeetingId = " + MeetingId;

                if (MeetingNoSearch == 1)
                    SQL_Query_Text += " AND (MeetingId BETWEEN " + FromMeetingId + " AND " + ToMeetingId + ")";
            }

            if (DepartmentId > 0)
                SQL_Query_Text += " AND DepartmentId = " + DepartmentId;

            if (ConfirmStatus >= 0)
                SQL_Query_Text += " AND IsConfirmed = " + ConfirmStatus;

            SQL_Query_Text += " ORDER BY CommitteeId, MeetingId, DepartmentId, IsConfirmed;";

            return ActionItemDB.GetFollowup(SQL_Query_Text);
        }
        #endregion


        #region GetAgendaSummaryReport
        public static DataTable GetAgendaSummaryReport(int CommitteeId, int DepartmentId, int MeetingNoSearch, int MeetingId, int FromMeetingId, int ToMeetingId,
            int SubjectNoSearch, int FromSubjectNo, int ToSubjectNo)
        {
            string SQL_Query_Text = string.Empty;

            if (CommitteeId > 0)
            {
                SQL_Query_Text += "SELECT * FROM View_Agenda WHERE AgendaStatusCode = 'ACA'";

                SQL_Query_Text += " AND CommitteeId = " + CommitteeId;

                if (DepartmentId > 0)
                    SQL_Query_Text += " AND DepartmentId = " + DepartmentId;

                if (MeetingNoSearch == 0)
                    if (MeetingId > 0)
                        SQL_Query_Text += " AND MeetingId = " + MeetingId;

                if (MeetingNoSearch == 1)
                    SQL_Query_Text += " AND (MeetingId BETWEEN " + FromMeetingId + " AND " + ToMeetingId + ")";

                if (SubjectNoSearch == 1)
                    SQL_Query_Text += " AND (SubjectNo BETWEEN " + FromSubjectNo + " AND " + ToSubjectNo + ")";
            }


            SQL_Query_Text += " ORDER BY CommitteeId, MeetingId, SubjectNo;";

            return CommonDB.GetDataTableFromQuery(SQL_Query_Text);
        }
        #endregion

        #region GetAgendaSummaryFullReport
        public static DataTable GetAgendaSummaryFullReport(int CommitteeId, int DepartmentId, int MeetingNoSearch, int MeetingId, int FromMeetingId, int ToMeetingId,
            int SubjectNoSearch, int FromSubjectNo, int ToSubjectNo)
        {
            string SQL_Query_Text = string.Empty;

            if (CommitteeId > 0)
            {
                SQL_Query_Text += "SELECT * FROM View_Agenda WHERE AgendaStatusCode = 'ACA'";

                SQL_Query_Text += " AND CommitteeId = " + CommitteeId;

                if (DepartmentId > 0)
                    SQL_Query_Text += " AND DepartmentId = " + DepartmentId;

                if (MeetingNoSearch == 0)
                    if (MeetingId > 0)
                        SQL_Query_Text += " AND MeetingId = " + MeetingId;

                if (MeetingNoSearch == 1)
                    SQL_Query_Text += " AND (MeetingId BETWEEN " + FromMeetingId + " AND " + ToMeetingId + ")";

                if (SubjectNoSearch == 1)
                    SQL_Query_Text += " AND (SubjectNo BETWEEN " + FromSubjectNo + " AND " + ToSubjectNo + ")";
            }


            SQL_Query_Text += " ORDER BY DepartmentId, MeetingId, SubjectNo;";

            return CommonDB.GetDataTableFromQuery(SQL_Query_Text);
        }
        #endregion

        #region GetAgendaDetailsReport
        public static DataTable GetAgendaDetailsReport(int CommitteeId, int DepartmentId, int MeetingNoSearch, int MeetingId, int FromMeetingId, int ToMeetingId,
            int SubjectNoSearch, int FromSubjectNo, int ToSubjectNo)
        {
            string SQL_Query_Text = string.Empty;

            if (CommitteeId > 0)
            {
                SQL_Query_Text += "SELECT * FROM View_Agenda WHERE AgendaStatusCode = 'ACA'";

                SQL_Query_Text += " AND CommitteeId = " + CommitteeId;

                if (DepartmentId > 0)
                    SQL_Query_Text += " AND DepartmentId = " + DepartmentId;

                if (MeetingNoSearch == 0)
                    if (MeetingId > 0)
                        SQL_Query_Text += " AND MeetingId = " + MeetingId;

                if (MeetingNoSearch == 1)
                    SQL_Query_Text += " AND (MeetingId BETWEEN " + FromMeetingId + " AND " + ToMeetingId + ")";

                if (SubjectNoSearch == 1)
                    SQL_Query_Text += " AND (SubjectNo BETWEEN " + FromSubjectNo + " AND " + ToSubjectNo + ")";
            }


            SQL_Query_Text += " ORDER BY CommitteeId, MeetingId, SubjectNo;";

            return CommonDB.GetDataTableFromQuery(SQL_Query_Text);
        }
        #endregion

        #region GetMinutesReport
        // Only meetings with finalized or confirmed minutes; same filters and order as the
        // query built here before (BMMS-Fix-MinutesGating-Step22.sql)
        public static DataTable GetMinutesReport(int CommitteeId, int DepartmentId, int MeetingNoSearch, int MeetingId, int FromMeetingId, int ToMeetingId,
            int SubjectNoSearch, int FromSubjectNo, int ToSubjectNo)
        {
            return MinutesDB.GetMinutesReport(CommitteeId, DepartmentId, MeetingNoSearch, MeetingId, FromMeetingId, ToMeetingId,
                SubjectNoSearch, FromSubjectNo, ToSubjectNo);
        }
        #endregion

        #region GetMinutesExtractReport
        // The extract used the same query as the minutes report, so it reads the same procedure
        public static DataTable GetMinutesExtractReport(int CommitteeId, int DepartmentId, int MeetingNoSearch, int MeetingId, int FromMeetingId, int ToMeetingId,
            int SubjectNoSearch, int FromSubjectNo, int ToSubjectNo)
        {
            return MinutesDB.GetMinutesReport(CommitteeId, DepartmentId, MeetingNoSearch, MeetingId, FromMeetingId, ToMeetingId,
                SubjectNoSearch, FromSubjectNo, ToSubjectNo);
        }
        #endregion

    }
    #endregion

}
