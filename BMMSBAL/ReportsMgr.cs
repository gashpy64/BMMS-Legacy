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
        public static DataTable GetMinutesReport(int CommitteeId, int DepartmentId, int MeetingNoSearch, int MeetingId, int FromMeetingId, int ToMeetingId, 
            int SubjectNoSearch, int FromSubjectNo, int ToSubjectNo)
        {
            string SQL_Query_Text = string.Empty;

            if (CommitteeId > 0)
            {
                SQL_Query_Text += "SELECT * FROM View_Minute WHERE 1=1";
            
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

        #region GetMinutesExtractReport
        public static DataTable GetMinutesExtractReport(int CommitteeId, int DepartmentId, int MeetingNoSearch, int MeetingId, int FromMeetingId, int ToMeetingId,
            int SubjectNoSearch, int FromSubjectNo, int ToSubjectNo)
        {
            string SQL_Query_Text = string.Empty;

            if (CommitteeId > 0)
            {
                SQL_Query_Text += "SELECT * FROM View_Minute WHERE 1=1";

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

    }
    #endregion

}
