using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;


namespace BMMSDAL
{
    #region MinutesDAL
    public class MinutesDAL
    {
        #region Properties

        private string _Code;
        private int _MinutesId;
        private int _DecisionTypeId;
        private DateTime? _DueDate;   // step UN6a: null = no due date (sent as DBNull)
        private string _Directions;
        private string _ActualResolution;
        private string _ShortText;
        private DateTime _CreatedOn;
        private int _CreatedBy;
        private DateTime _UpdatedOn;
        private int _UpdatedBy;

        public string Code
        {
            get { return _Code; }
            set { _Code = value; }
        }
        public int MinutesId
        {
            get { return _MinutesId; }
            set { _MinutesId = value; }
        }
        public int DecisionTypeId
        {
            get { return _DecisionTypeId; }
            set { _DecisionTypeId = value; }
        }
        public DateTime? DueDate
        {
            get { return _DueDate; }
            set { _DueDate = value; }
        }
        // Step UN6a1: send @DueDate (only Save minutes does, and only when step 38 is installed)
        public bool SendDueDate { get; set; }
        public string Directions
        {
            get { return _Directions; }
            set { _Directions = value; }
        }
        public string ActualResolution
        {
            get { return _ActualResolution; }
            set { _ActualResolution = value; }
        }
        public string ShortText
        {
            get { return _ShortText; }
            set { _ShortText = value; }
        }
        public DateTime CreatedOn
        {
            get { return _CreatedOn; }
            set { _CreatedOn = value; }
        }
        public int CreatedBy
        {
            get { return _CreatedBy; }
            set { _CreatedBy = value; }
        }
        public DateTime UpdatedOn
        {
            get { return _UpdatedOn; }
            set { _UpdatedOn = value; }
        }
        public int UpdatedBy
        {
            get { return _UpdatedBy; }
            set { _UpdatedBy = value; }
        }

        #endregion
    }
    #endregion

    #region MinutesDALList
    public class MinutesDALList : List<MinutesDAL>
    {
        #region MinutesDALList
        public MinutesDALList()
        {

        }
        #endregion
    }
    #endregion

    #region MinutesDB
    public class MinutesDB
    {

        #region GetMinutesByMeetingId
        public static DataTable GetMinutesByMeetingId(int MeetingId, int StatusId, int DepartmentId)
        {
            SqlParameter[] parameter = new SqlParameter[3];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);
            parameter[1] = new SqlParameter("@StatusId", StatusId);
            parameter[2] = new SqlParameter("@DepartmentId", DepartmentId);

            return CommonDB.GetDataTable("spr_GetMinutesByMeetingId", parameter); ;
        }
        #endregion

        #region GetMinutesByMeetingNoFromTo
        public static DataTable GetMinutesByMeetingNoFromTo(int CommitteeId, int MeetingNoFrom, int MeetingNoTo, int StatusId, int DepartmentId)
        {
            SqlParameter[] parameter = new SqlParameter[5];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);
            parameter[1] = new SqlParameter("@MeetingNoFrom", MeetingNoFrom);
            parameter[2] = new SqlParameter("@MeetingNoTo", MeetingNoTo);
            parameter[3] = new SqlParameter("@StatusId", StatusId);
            parameter[4] = new SqlParameter("@DepartmentId", DepartmentId);

            return CommonDB.GetDataTable("spr_GetMinutesByMeetingNoFromTo", parameter); ;
        }
        #endregion

        #region GetMinutesReport
        // Minutes and Minutes Extract reports: only meetings with finalized or confirmed minutes (BMMS-Fix-MinutesGating-Step22.sql)
        public static DataTable GetMinutesReport(int CommitteeId, int DepartmentId, int MeetingNoSearch, int MeetingId, int FromMeetingId, int ToMeetingId,
            int SubjectNoSearch, int FromSubjectNo, int ToSubjectNo)
        {
            SqlParameter[] parameter = new SqlParameter[9];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);
            parameter[1] = new SqlParameter("@DepartmentId", DepartmentId);
            parameter[2] = new SqlParameter("@MeetingNoSearch", MeetingNoSearch);
            parameter[3] = new SqlParameter("@MeetingId", MeetingId);
            parameter[4] = new SqlParameter("@FromMeetingId", FromMeetingId);
            parameter[5] = new SqlParameter("@ToMeetingId", ToMeetingId);
            parameter[6] = new SqlParameter("@SubjectNoSearch", SubjectNoSearch);
            parameter[7] = new SqlParameter("@FromSubjectNo", FromSubjectNo);
            parameter[8] = new SqlParameter("@ToSubjectNo", ToSubjectNo);

            return CommonDB.GetDataTable("spr_GetMinutesReport", parameter);
        }
        #endregion

        #region GetMinutesReportMeetings
        // Meetings of a committee with finalized or confirmed minutes, for the minutes report lists (BMMS-Fix-MinutesGating-Step22.sql)
        public static DataTable GetMinutesReportMeetings(int CommitteeId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);

            return CommonDB.GetDataTable("spr_GetMinutesReportMeetings", parameter);
        }
        #endregion

        #region GetMinutesReportAllStatus
        // Step RA1b (BMMS-Fix-ReportAccess-Step41.sql): the Minutes report rows in every minutes status, with
        // MinutesStatus and MinutesStatusMark, for the Controller and Management only. The procedure checks the
        // acting user in the database: Reason 8 (missing or inactive) or 4 (another role), then no rows.
        // Reason comes back 0 when allowed.
        public static DataTable GetMinutesReportAllStatus(int CommitteeId, int DepartmentId, int MeetingNoSearch, int MeetingId, int FromMeetingId, int ToMeetingId,
            int SubjectNoSearch, int FromSubjectNo, int ToSubjectNo, int ActingUserId, out int Reason)
        {
            SqlParameter result = new SqlParameter("@Result", SqlDbType.Int);
            result.Direction = ParameterDirection.Output;
            SqlParameter reason = new SqlParameter("@Reason", SqlDbType.Int);
            reason.Direction = ParameterDirection.Output;

            SqlParameter[] parameter = new SqlParameter[12];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);
            parameter[1] = new SqlParameter("@DepartmentId", DepartmentId);
            parameter[2] = new SqlParameter("@MeetingNoSearch", MeetingNoSearch);
            parameter[3] = new SqlParameter("@MeetingId", MeetingId);
            parameter[4] = new SqlParameter("@FromMeetingId", FromMeetingId);
            parameter[5] = new SqlParameter("@ToMeetingId", ToMeetingId);
            parameter[6] = new SqlParameter("@SubjectNoSearch", SubjectNoSearch);
            parameter[7] = new SqlParameter("@FromSubjectNo", FromSubjectNo);
            parameter[8] = new SqlParameter("@ToSubjectNo", ToSubjectNo);
            parameter[9] = new SqlParameter("@ActingUserId", ActingUserId);
            parameter[10] = result;
            parameter[11] = reason;

            DataTable dt = CommonDB.GetDataTable("spr_GetMinutesReportAllStatus", parameter);
            Reason = RefusalReason(result, reason);
            return dt;
        }
        #endregion

        #region GetMinutesReportMeetingsAllStatus
        // Step RA1b (BMMS-Fix-ReportAccess-Step41.sql): the meetings of a committee in every minutes status that have
        // at least one minutes row, with MinutesStatusMark, for the Controller and Management only (Reason 8 or 4
        // as above, then no rows; 0 when allowed)
        public static DataTable GetMinutesReportMeetingsAllStatus(int CommitteeId, int ActingUserId, out int Reason)
        {
            SqlParameter result = new SqlParameter("@Result", SqlDbType.Int);
            result.Direction = ParameterDirection.Output;
            SqlParameter reason = new SqlParameter("@Reason", SqlDbType.Int);
            reason.Direction = ParameterDirection.Output;

            SqlParameter[] parameter = new SqlParameter[4];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);
            parameter[1] = new SqlParameter("@ActingUserId", ActingUserId);
            parameter[2] = result;
            parameter[3] = reason;

            DataTable dt = CommonDB.GetDataTable("spr_GetMinutesReportMeetingsAllStatus", parameter);
            Reason = RefusalReason(result, reason);
            return dt;
        }
        #endregion

        #region RefusalReason
        // Step RA1b: 0 when @Result is 1; otherwise @Reason (8 when the procedure gave none)
        public static int RefusalReason(SqlParameter Result, SqlParameter Reason)
        {
            if (Result.Value != null && Result.Value != DBNull.Value && Convert.ToInt32(Result.Value) == 1)
                return 0;
            if (Reason.Value != null && Reason.Value != DBNull.Value && Convert.ToInt32(Reason.Value) > 0)
                return Convert.ToInt32(Reason.Value);
            return 8;
        }
        #endregion

        #region GetMinutesByMeetingIdAgendaId
        public static DataTable GetMinutesByMeetingIdAgendaId(int MeetingId, int AgendaId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);
            parameter[1] = new SqlParameter("@AgendaId", AgendaId);

            return CommonDB.GetDataTable("spr_GetMinutesByMeetingIdAgendaId", parameter); ;
        }
        #endregion

        #region GetMinutesByMinutesId
        public static DataTable GetMinutesByMinutesId(int MinutesId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MinutesId", MinutesId);

            return CommonDB.GetDataTable("spr_GetMinutesByMinutesId", parameter); ;
        }
        #endregion

        #region UpdateMinutes
        public static DataTable UpdateMinutes(MinutesDAL myMinutesDAL)
        {
            // Step UN6a1: @DueDate only when the caller asks for it and the procedure has it (HasDueDateParameter);
            // without it the procedure keeps the stored due date, and without step 38 the call still works
            SqlParameter[] parameter = new SqlParameter[myMinutesDAL.SendDueDate ? 9 : 8];
            parameter[0] = new SqlParameter("@Code", myMinutesDAL.Code);
            parameter[1] = new SqlParameter("@MinutesId", myMinutesDAL.MinutesId);
            parameter[2] = new SqlParameter("@DecisionTypeId", myMinutesDAL.DecisionTypeId);
            parameter[3] = new SqlParameter("@Directions", myMinutesDAL.Directions);
            parameter[4] = new SqlParameter("@ActualResolution", myMinutesDAL.ActualResolution);
            parameter[5] = new SqlParameter("@ShortText", myMinutesDAL.ShortText);
            parameter[6] = new SqlParameter("@CreatedBy", myMinutesDAL.CreatedBy);
            parameter[7] = new SqlParameter("@UpdatedBy", myMinutesDAL.UpdatedBy);

            // Step UN6a (BMMS-Fix-MinutesDueDate-Step38.sql): the due date as datetime, NULL for none; the procedure
            // keeps it only for Code 'All' and a Followup decision, and refuses a date before the meeting date (Reason 22)
            if (myMinutesDAL.SendDueDate)
            {
                parameter[8] = new SqlParameter("@DueDate", SqlDbType.DateTime);
                parameter[8].Value = myMinutesDAL.DueDate.HasValue ? (object)myMinutesDAL.DueDate.Value.Date : DBNull.Value;
            }

            // One row: Result, Reason, ReasonDetail; refused once the minutes are confirmed (BMMS-Fix-MeetingLocks-Step16.sql)
            return CommonDB.GetDataTable("spr_UpdateMinutes", parameter);
        }
        #endregion

        #region HasDueDateParameter
        // Step UN6a1: true when spr_UpdateMinutes has the step 38 parameter @DueDate (BMMS-Fix-MinutesDueDate-Step38.sql)
        public static bool HasDueDateParameter()
        {
            DataTable dt = CommonDB.GetDataTableFromQuery(
                "SELECT COUNT(*) AS n FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_UpdateMinutes') AND name = '@DueDate'");
            return dt.Rows.Count > 0 && Convert.ToInt32(dt.Rows[0]["n"]) > 0;
        }
        #endregion
    }
    #endregion
    
}
