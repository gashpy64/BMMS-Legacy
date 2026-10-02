using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region AttendanceBAL
    public class AttendanceBAL
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

    #region AttendanceBALList
    public class AttendanceBALList : List<AttendanceBAL>
    {
        #region public AttendanceBALList()
        public AttendanceBALList()
        {

        }
        #endregion
    }
    #endregion

    #region AttendanceMgr
    public class AttendanceMgr
    {
        #region UpdateAttendance
        public static int UpdateAttendance(AttendanceBAL AttendanceBAL)
        {
            AttendanceDAL AttendanceDAL = new AttendanceDAL();

            AttendanceDAL.CommitteeId = AttendanceBAL.CommitteeId;
            AttendanceDAL.MeetingId = AttendanceBAL.MeetingId;
            AttendanceDAL.MemberOf = AttendanceBAL.MemberOf;
            AttendanceDAL.MemberId = AttendanceBAL.MemberId;
            AttendanceDAL.Attendance = AttendanceBAL.Attendance;
            AttendanceDAL.UpdatedBy = AttendanceBAL.UpdatedBy;

            return AttendanceDB.UpdateAttendance(AttendanceDAL);
        }
        #endregion   
    
        #region GetAttendanceByMeetingId
        public static DataTable GetAttendanceByMeetingId(int MeetingId, string MemberOf)
        {
            return AttendanceDB.GetAttendanceByMeetingId(MeetingId, MemberOf);
        }
        #endregion

        #region GetAttendanceMembersByDesignId
        public static DataTable GetAttendanceMembersByDesignId(int DesignationId, DateTime FromDate, DateTime ToDate)
        {
            return AttendanceDB.GetAttendanceMembersByDesignId(DesignationId, FromDate, ToDate);
        }
        #endregion

        #region GetTotAmtByMemberId
        public static DataTable GetTotAmtByMemberId(int MemberId, DateTime FromDate, DateTime ToDate)
        {
            return AttendanceDB.GetTotAmtByMemberId(MemberId, FromDate, ToDate);
        }
        #endregion

        #region GetAttendanceByMemberId
        public static DataTable GetAttendanceByMemberId(int MemberId, DateTime FromDate, DateTime ToDate)
        {
            return AttendanceDB.GetAttendanceByMemberId(MemberId, FromDate, ToDate);
        }
        #endregion
    }
    #endregion



}
