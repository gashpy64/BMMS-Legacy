using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;


namespace BMMSDAL
{
    #region MeetingMemberDAL
    public class MeetingMemberDAL
    {
        #region Properties

        private string _Code;
        private int _MeetingMemberId;
        private int _MeetingId;
        private int _MemberId;
        private int _MemberTypeId;
        private int _StatusId;
        private DateTime _CreatedOn;
        private int _CreatedBy;
        private DateTime _UpdatedOn;
        private int _UpdatedBy;

        public string Code
        {
            get { return _Code; }
            set { _Code = value; }
        }
        public int MeetingMemberId
        {
            get { return _MeetingMemberId; }
            set { _MeetingMemberId = value; }
        }
        public int MeetingId
        {
            get { return _MeetingId; }
            set { _MeetingId = value; }
        }
        public int MemberId
        {
            get { return _MemberId; }
            set { _MemberId = value; }
        }
        public int MemberTypeId
        {
            get { return _MemberTypeId; }
            set { _MemberTypeId = value; }
        }
        public int StatusId
        {
            get { return _StatusId; }
            set { _StatusId = value; }
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

    #region MeetingMemberDALList
    public class MeetingMemberDALList : List<MeetingMemberDAL>
    {
        #region MeetingMemberDALList
        public MeetingMemberDALList()
        {

        }
        #endregion
    }
    #endregion

    #region MeetingMemberDB
    public class MeetingMemberDB
    {

        #region GetNextMeetingMemberCode
        public static string GetNextMeetingMemberCode()
        {
            DataTable dt = new DataTable();
            dt = CommonDB.GetDataTable("spr_GetNextMeetingMemberCode", null);

            return dt.Rows[0]["NextMeetingMemberCode"].ToString();
        }
        #endregion

        #region GetMeetingMemberByMeetingId
        public static DataTable GetMeetingMemberByMeetingId(int MeetingId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);

            return CommonDB.GetDataTable("spr_GetMeetingMemberByMeetingId", parameter);
        }
        #endregion

        #region GetMeetingMemberByMeetingIdMemberTypeId
        public static DataTable GetMeetingMemberByMeetingIdMemberTypeId(int MeetingId, int MemberTypeId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);
            parameter[1] = new SqlParameter("@MemberTypeId", MemberTypeId);

            return CommonDB.GetDataTable("spr_GetMeetingMemberByMeetingIdMemberTypeId", parameter);
        }
        #endregion

        #region GetMeetingMemberByMeetingMemberId
        public static DataTable GetMeetingMemberByMeetingMemberId(int MeetingMemberId)
        {
            DataTable dt = new DataTable();

            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MeetingMemberId", MeetingMemberId);

            dt = CommonDB.GetDataTable("spr_GetMeetingMemberByMeetingMemberId", parameter);

            return dt;
        }
        #endregion

        #region AddEditMeetingMember
        public static int AddEditMeetingMember(MeetingMemberDAL MeetingMemberDAL)
        {
            SqlParameter[] parameter = new SqlParameter[10];
            parameter[0] = new SqlParameter("@Code", MeetingMemberDAL.Code);
            parameter[1] = new SqlParameter("@MeetingMemberId", MeetingMemberDAL.MeetingMemberId);
            parameter[2] = new SqlParameter("@MeetingId", MeetingMemberDAL.MeetingId);
            parameter[3] = new SqlParameter("@MemberId", MeetingMemberDAL.MemberId);
            parameter[4] = new SqlParameter("@MemberTypeId", MeetingMemberDAL.MemberTypeId);
            parameter[5] = new SqlParameter("@StatusId", MeetingMemberDAL.StatusId);
            parameter[6] = new SqlParameter("@CreatedOn", MeetingMemberDAL.CreatedOn);
            parameter[7] = new SqlParameter("@CreatedBy", MeetingMemberDAL.CreatedBy);
            parameter[8] = new SqlParameter("@UpdatedOn", MeetingMemberDAL.UpdatedOn);
            parameter[9] = new SqlParameter("@UpdatedBy", MeetingMemberDAL.UpdatedBy);

            return CommonDB.ExecuteProcedure("spr_AddEditMeetingMember", parameter);
        }
        #endregion

        #region DeleteMeetingMemberByMeetingMemberId
        public static int DeleteMeetingMemberByMeetingMemberId(int MeetingMemberId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MeetingMemberId", MeetingMemberId);

            DataTable dtResult = new DataTable();
            dtResult = CommonDB.GetDataTable("spr_DeleteMeetingMemberByMeetingMemberId", parameter);

            return Convert.ToInt16(dtResult.Rows[0]["Result"].ToString());
        }
        #endregion
    }
    #endregion

}
