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
        private DateTime _DueDate = System.DateTime.Now;
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
        public DateTime DueDate
        {
            get { return _DueDate; }
            set { _DueDate = value; }
        }
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
        public static int UpdateMinutes(MinutesDAL myMinutesDAL)
        {
            SqlParameter[] parameter = new SqlParameter[8];
            parameter[0] = new SqlParameter("@Code", myMinutesDAL.Code);
            parameter[1] = new SqlParameter("@MinutesId", myMinutesDAL.MinutesId);
            parameter[2] = new SqlParameter("@DecisionTypeId", myMinutesDAL.DecisionTypeId);
            //parameter[3] = new SqlParameter("@DueDate", myMinutesDAL.DueDate);
            parameter[3] = new SqlParameter("@Directions", myMinutesDAL.Directions);
            parameter[4] = new SqlParameter("@ActualResolution", myMinutesDAL.ActualResolution);
            parameter[5] = new SqlParameter("@ShortText", myMinutesDAL.ShortText);
            parameter[6] = new SqlParameter("@CreatedBy", myMinutesDAL.CreatedBy);
            parameter[7] = new SqlParameter("@UpdatedBy", myMinutesDAL.UpdatedBy);

            return CommonDB.ExecuteProcedure("spr_UpdateMinutes", parameter); ;
        }
        #endregion
    }
    #endregion
    
}
