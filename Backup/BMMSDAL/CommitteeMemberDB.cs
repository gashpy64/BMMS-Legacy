using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;


namespace BMMSDAL
{
    #region CommitteeMemberDAL
    public class CommitteeMemberDAL
    {
        #region Properties

        private string _Code;
        private int _CommitteeMemberId;
        private int _CommitteeId;
        private int _MemberId;
        private int _MemberTypeId;
        private DateTime _AppointmentDate;
        private String _CessationDate;
        private int _IsFeeApplicable;
        private decimal _ApplicableFee;
        private DateTime _CreatedOn;
        private int _CreatedBy;
        private DateTime _UpdatedOn;
        private int _UpdatedBy;

        public string Code
        {
            get { return _Code; }
            set { _Code = value; }
        }
        public int CommitteeMemberId
        {
            get { return _CommitteeMemberId; }
            set { _CommitteeMemberId = value; }
        }
        public int CommitteeId
        {
            get { return _CommitteeId; }
            set { _CommitteeId = value; }
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
        public DateTime AppointmentDate
        {
            get { return _AppointmentDate; }
            set { _AppointmentDate = value; }
        }
        public String CessationDate
        {
            get { return _CessationDate; }
            set { _CessationDate = value; }
        }
        public int IsFeeApplicable
        {
            get { return _IsFeeApplicable; }
            set { _IsFeeApplicable = value; }
        }
        public decimal ApplicableFee
        {
            get { return _ApplicableFee; }
            set { _ApplicableFee = value; }
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

    #region CommitteeMemberDALList
    public class CommitteeMemberDALList : List<CommitteeMemberDAL>
    {
        #region CommitteeMemberDALList
        public CommitteeMemberDALList()
        {

        }
        #endregion
    }
    #endregion

    #region CommitteeMemberDB
    public class CommitteeMemberDB
    {

        #region GetCommitteeMemberList
        public static DataTable GetCommitteeMemberList()
        {
            return CommonDB.GetDataTable("spr_GetCommitteeMember", null); ;
        }
        #endregion

        #region GetNextCommitteeMemberCode
        public static string GetNextCommitteeMemberCode()
        {
            DataTable dt = new DataTable();
            dt = CommonDB.GetDataTable("spr_GetNextCommitteeMemberCode", null);

            return dt.Rows[0]["NextCommitteeMemberCode"].ToString();
        }
        #endregion

        #region GetCommitteeMemberByCommitteeId
        public static DataTable GetCommitteeMemberByCommitteeId(int CommitteeId, int MeetingId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);
            parameter[1] = new SqlParameter("@MeetingId", MeetingId);

            return CommonDB.GetDataTable("spr_GetCommitteeMemberByCommitteeId", parameter);
        }
        #endregion

        #region GetCommitteeMemberByMeetingId
        public static DataTable GetCommitteeMemberByMeetingId(int MeetingId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);

            return CommonDB.GetDataTable("spr_GetCommitteeMemberByMeetingId", parameter);
        }
        #endregion

        #region GetPresentCommitteeMemberByCommitteeId
        public static DataTable GetPresentCommitteeMemberByCommitteeId(int CommitteeId, int MeetingId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);
            parameter[1] = new SqlParameter("@MeetingId", MeetingId);

            return CommonDB.GetDataTable("spr_GetPresentCommitteeMemberByCommitteeId", parameter);
        }
        #endregion

        #region GetSittingFeesApplicable
        public static DataTable GetSittingFeesApplicable(int MeetingId, int CommitteeId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);
            parameter[1] = new SqlParameter("@CommitteeId", CommitteeId);

            return CommonDB.GetDataTable("spr_GetSittingFeesApplicable", parameter);
        }
        #endregion

        #region GetCommitteeMemberByCommitteeMemberId
        public static DataTable GetCommitteeMemberByCommitteeMemberId(int CommitteeMemberId)
        {
            DataTable dt = new DataTable();

            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@CommitteeMemberId", CommitteeMemberId);

            dt = CommonDB.GetDataTable("spr_GetCommitteeMemberByCommitteeMemberId", parameter);

            return dt;
        }
        #endregion

        #region AddEditCommitteeMember
        public static int AddEditCommitteeMember(CommitteeMemberDAL CommitteeMemberDAL)
        {
            SqlParameter[] parameter = new SqlParameter[13];
            parameter[0] = new SqlParameter("@Code", CommitteeMemberDAL.Code);
            parameter[1] = new SqlParameter("@CommitteeMemberId", CommitteeMemberDAL.CommitteeMemberId);
            parameter[2] = new SqlParameter("@CommitteeId", CommitteeMemberDAL.CommitteeId);
            parameter[3] = new SqlParameter("@MemberId", CommitteeMemberDAL.MemberId);
            parameter[4] = new SqlParameter("@MemberTypeId", CommitteeMemberDAL.MemberTypeId);
            parameter[5] = new SqlParameter("@AppointmentDate", CommitteeMemberDAL.AppointmentDate);
            parameter[6] = new SqlParameter("@CessationDate", CommitteeMemberDAL.CessationDate);
            parameter[7] = new SqlParameter("@IsFeeApplicable", CommitteeMemberDAL.IsFeeApplicable);
            parameter[8] = new SqlParameter("@ApplicableFee", CommitteeMemberDAL.ApplicableFee);
            parameter[9] = new SqlParameter("@CreatedOn", CommitteeMemberDAL.CreatedOn);
            parameter[10] = new SqlParameter("@CreatedBy", CommitteeMemberDAL.CreatedBy);
            parameter[11] = new SqlParameter("@UpdatedOn", CommitteeMemberDAL.UpdatedOn);
            parameter[12] = new SqlParameter("@UpdatedBy", CommitteeMemberDAL.UpdatedBy);

            return CommonDB.ExecuteProcedure("spr_AddEditCommitteeMember", parameter);
        }
        #endregion

        #region DeleteCommitteeMemberByCommitteeMemberId
        public static int DeleteCommitteeMemberByCommitteeMemberId(int CommitteeMemberId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@CommitteeMemberId", CommitteeMemberId);

            return CommonDB.ExecuteProcedure("spr_DeleteCommitteeMemberByCommitteeMemberId", parameter); ;
        }
        #endregion
    }
    #endregion

}
