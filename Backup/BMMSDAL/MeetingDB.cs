using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;


namespace BMMSDAL
{
    #region MeetingDAL
    public class MeetingDAL
    {
        #region Properties

        private string _Code;
        private int _MeetingId;
        private string _MeetingNo;
        private int _CommitteeId;
        private string _Place;
        private string _Venue;
        private DateTime _MeetingDate;
        private string _MeetingTime;
        private DateTime _AgendaSubmissionDate;
        private string _MeetingColorCode;
        private DateTime _CreatedOn;
        private int _CreatedBy;
        private DateTime _UpdatedOn;
        private int _UpdatedBy;

        public string Code
        {
            get { return _Code; }
            set { _Code = value; }
        }
        public int MeetingId
        {
            get { return _MeetingId; }
            set { _MeetingId = value; }
        }
        public string MeetingNo
        {
            get { return _MeetingNo; }
            set { _MeetingNo = value; }
        }
        public int CommitteeId
        {
            get { return _CommitteeId; }
            set { _CommitteeId = value; }
        }
        public string Place
        {
            get { return _Place; }
            set { _Place = value; }
        }
        public string Venue
        {
            get { return _Venue; }
            set { _Venue = value; }
        }

        public DateTime MeetingDate
        {
            get { return _MeetingDate; }
            set { _MeetingDate = value; }
        }
        public string MeetingTime
        {
            get { return _MeetingTime; }
            set { _MeetingTime = value; }
        }
        public DateTime AgendaSubmissionDate
        {
            get { return _AgendaSubmissionDate; }
            set { _AgendaSubmissionDate = value; }
        }
        public string MeetingColorCode
        {
            get { return _MeetingColorCode; }
            set { _MeetingColorCode = value; }
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

    #region MeetingDALList
    public class MeetingDALList : List<MeetingDAL>
    {
        #region MeetingDALList
        public MeetingDALList()
        {

        }
        #endregion
    }
    #endregion

    #region MeetingDB
    public class MeetingDB
    {

        #region GetMeetingList
        public static DataTable GetMeetingList()
        {
            return CommonDB.GetDataTable("spr_GetMeeting", null); ;
        }
        #endregion

        #region GetScheduleMeet
        public static DataTable GetScheduleMeet(string Code)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@Code", Code);

            return CommonDB.GetDataTable("spr_GetScheduleMeet", parameter); ;
        }
        #endregion

        #region GetMeetingByCommitteeId
        public static DataTable GetMeetingByCommitteeId(int CommitteeId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);

            return CommonDB.GetDataTable("spr_GetMeetingByCommitteeId", parameter); ;
        }
        #endregion

        #region GetMeetingForController
        public static DataTable GetMeetingForController(int CommitteeId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);

            return CommonDB.GetDataTable("spr_GetMeetingForController", parameter); ;
        }
        #endregion

        #region GetMeetingForUsers
        public static DataTable GetMeetingForUsers(int CommitteeId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);

            return CommonDB.GetDataTable("spr_GetMeetingForUsers", parameter); ;
        }
        #endregion

        #region GetLastMeetingByCommitteeId
        public static DataTable GetLastMeetingByCommitteeId(int CommitteeId, int MeetingId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);
            parameter[1] = new SqlParameter("@MeetingId", MeetingId);

            return CommonDB.GetDataTable("spr_GetLastMeetingByCommitteeId", parameter); ;
        }
        #endregion

        #region GetMeetingFullMember
        public static DataTable GetMeetingFullMember(int MeetingId, int CommitteeId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);
            parameter[1] = new SqlParameter("@CommitteeId", CommitteeId);

            return CommonDB.GetDataTable("spr_GetMeetingFullMember", parameter); ;
        }
        #endregion

        #region GetNextMeetingNo
        public static string GetNextMeetingNo(int CommitteeId)
        {
            DataTable dt = new DataTable();
            
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);

            dt = CommonDB.GetDataTable("spr_GetNextMeetingNo", parameter);

            return dt.Rows[0]["NextMeetingNo"].ToString();
        }
        #endregion

        #region GetMeetingByMeetingId
        public static DataTable GetMeetingByMeetingId(int MeetingId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);

            return CommonDB.GetDataTable("spr_GetMeetingByMeetingId", parameter);
        }
        #endregion

        #region GetMeetingByMeetingNoFromTo
        public static DataTable GetMeetingByMeetingNoFromTo(int CommitteeId, int MeetingIdFrom, int MeetingIdTo)
        {
            SqlParameter[] parameter = new SqlParameter[3];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);
            parameter[1] = new SqlParameter("@MeetingIdFrom", MeetingIdFrom);
            parameter[2] = new SqlParameter("@MeetingIdTo", MeetingIdTo);

            return CommonDB.GetDataTable("spr_GetMeetingByMeetingNoFromTo", parameter);
        }
        #endregion

        #region GetMeetingByFromToDate
        public static DataTable GetMeetingByFromToDate(int CommitteeId, DateTime FromDate, DateTime ToDate)
        {
            SqlParameter[] parameter = new SqlParameter[3];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);
            parameter[1] = new SqlParameter("@FromDate", FromDate);
            parameter[2] = new SqlParameter("@ToDate", ToDate);

            return CommonDB.GetDataTable("spr_GetMeetingByFromToDate", parameter);
        }
        #endregion

        #region GetMeetingChairman
        public static DataTable GetMeetingChairman(int MeetingId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);

            return CommonDB.GetDataTable("spr_GetMeetingChairman", parameter);

        }
        #endregion

        #region AddEditMeeting
        public static int AddEditMeeting(MeetingDAL MeetingDAL)
        {
            SqlParameter[] parameter = new SqlParameter[14];
            parameter[0] = new SqlParameter("@Code", MeetingDAL.Code);
            parameter[1] = new SqlParameter("@MeetingId", MeetingDAL.MeetingId);
            parameter[2] = new SqlParameter("@MeetingNo", MeetingDAL.MeetingNo);
            parameter[3] = new SqlParameter("@CommitteeId", MeetingDAL.CommitteeId);
            parameter[4] = new SqlParameter("@Place", MeetingDAL.Place);
            parameter[5] = new SqlParameter("@Venue", MeetingDAL.Venue);
            parameter[6] = new SqlParameter("@MeetingDate", MeetingDAL.MeetingDate);
            parameter[7] = new SqlParameter("@MeetingTime", MeetingDAL.MeetingTime);
            parameter[8] = new SqlParameter("@AgendaSubmissionDate", MeetingDAL.AgendaSubmissionDate);
            parameter[9] = new SqlParameter("@MeetingColorCode", MeetingDAL.MeetingColorCode);
            parameter[10] = new SqlParameter("@CreatedOn", MeetingDAL.CreatedOn);
            parameter[11] = new SqlParameter("@CreatedBy", MeetingDAL.CreatedBy);
            parameter[12] = new SqlParameter("@UpdatedOn", MeetingDAL.UpdatedOn);
            parameter[13] = new SqlParameter("@UpdatedBy", MeetingDAL.UpdatedBy);

            return CommonDB.ExecuteProcedure("spr_AddEditMeeting", parameter);
        }
        #endregion

        #region UpdateMeetingChairman
        public static int UpdateMeetingChairman(int MeetingId, int CommitteeId, int ChairmanNameId)
        {
            SqlParameter[] parameter = new SqlParameter[3];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);
            parameter[1] = new SqlParameter("@CommitteeId", CommitteeId);
            parameter[2] = new SqlParameter("@ChairmanNameId", ChairmanNameId);

            return CommonDB.ExecuteProcedure("spr_UpdateMeetingChairman", parameter);
        }
        #endregion

        #region DeleteMeetingByMeetingId
        public static int DeleteMeetingByMeetingId(int MeetingId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);

            DataTable dtResult = new DataTable();
            dtResult = CommonDB.GetDataTable("spr_DeleteMeetingByMeetingId", parameter);

            return Convert.ToInt16(dtResult.Rows[0]["Result"].ToString());
        }
        #endregion
    }
    #endregion

}
