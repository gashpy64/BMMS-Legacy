using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;


namespace BMMSDAL
{
    #region AttendanceDAL
    public class AttendanceDAL
    {
        #region Properties

        private string _Code;
        private int _AttendanceId;
        private int _CommitteeId;
        private int _MeetingId;
        private string _MemberOf;
        private int _MemberId;
        private string _Attendance;
        private DateTime _CreatedOn;
        private int _CreatedBy;
        private DateTime _UpdatedOn;
        private int _UpdatedBy;

        public string Code
        {
            get { return _Code; }
            set { _Code = value; }
        }
        public int AttendanceId
        {
            get { return _AttendanceId; }
            set { _AttendanceId = value; }
        }
        public int CommitteeId
        {
            get { return _CommitteeId; }
            set { _CommitteeId = value; }
        }
        public int MeetingId
        {
            get { return _MeetingId; }
            set { _MeetingId = value; }
        }
        public string MemberOf
        {
            get { return _MemberOf; }
            set { _MemberOf = value; }
        }
        public int MemberId
        {
            get { return _MemberId; }
            set { _MemberId = value; }
        }
        public string Attendance
        {
            get { return _Attendance; }
            set { _Attendance = value; }
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

    #region AttendanceDALList
    public class AttendanceDALList : List<AttendanceDAL>
    {
        #region AttendanceDALList
        public AttendanceDALList()
        {

        }
        #endregion
    }
    #endregion

    #region AttendanceDB
    public class AttendanceDB
    {
        #region UpdateAttendance
        public static int UpdateAttendance(AttendanceDAL AttendanceDAL)
        {
            SqlParameter[] parameter = new SqlParameter[6];
            parameter[0] = new SqlParameter("@CommitteeId", AttendanceDAL.CommitteeId);
            parameter[1] = new SqlParameter("@MeetingId", AttendanceDAL.MeetingId);
            parameter[2] = new SqlParameter("@MemberOf", AttendanceDAL.MemberOf);
            parameter[3] = new SqlParameter("@MemberId", AttendanceDAL.MemberId);
            parameter[4] = new SqlParameter("@Attendance", AttendanceDAL.Attendance);
            parameter[5] = new SqlParameter("@UpdatedBy", AttendanceDAL.UpdatedBy);

            return CommonDB.ExecuteProcedure("spr_UpdateAttendance", parameter);
        }
        #endregion

        #region GetAttendanceByMeetingId
        public static DataTable GetAttendanceByMeetingId(int MeetingId, string MemberOf)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);
            parameter[1] = new SqlParameter("@MemberOf", MemberOf);

            return CommonDB.GetDataTable("spr_GetAttendanceByMeetingId", parameter);
        }
        #endregion

        #region GetAttendanceMembersByDesignId
        public static DataTable GetAttendanceMembersByDesignId(int DesignationId, DateTime FromDate, DateTime ToDate)
        {
            SqlParameter[] parameter = new SqlParameter[3];
            parameter[0] = new SqlParameter("@DesignationId", DesignationId);
            parameter[1] = new SqlParameter("@FromDate", FromDate);
            parameter[2] = new SqlParameter("@ToDate", ToDate);

            return CommonDB.GetDataTable("spr_GetAttendanceMembersByDesignId", parameter);
        }
        #endregion

        #region GetTotAmtByMemberId
        public static DataTable GetTotAmtByMemberId(int MemberId, DateTime FromDate, DateTime ToDate)
        {
            SqlParameter[] parameter = new SqlParameter[3];
            parameter[0] = new SqlParameter("@MemberId", MemberId);
            parameter[1] = new SqlParameter("@FromDate", FromDate);
            parameter[2] = new SqlParameter("@ToDate", ToDate);

            return CommonDB.GetDataTable("spr_GetTotAmtByMemberId", parameter);
        }
        #endregion

        #region GetAttendanceByMemberId
        public static DataTable GetAttendanceByMemberId(int MemberId, DateTime FromDate, DateTime ToDate)
        {
            SqlParameter[] parameter = new SqlParameter[3];
            parameter[0] = new SqlParameter("@MemberId", MemberId);
            parameter[1] = new SqlParameter("@FromDate", FromDate);
            parameter[2] = new SqlParameter("@ToDate", ToDate);

            return CommonDB.GetDataTable("spr_GetAttendanceByMemberId", parameter);
        }
        #endregion
    }
    #endregion
    
}
