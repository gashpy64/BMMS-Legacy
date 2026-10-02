using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region CommitteeMemberBAL
    public class CommitteeMemberBAL
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

    #region CommitteeMemberBALList
    public class CommitteeMemberBALList : List<CommitteeMemberBAL>
    {
        #region public CommitteeMemberBALList()
        public CommitteeMemberBALList()
        {

        }
        #endregion
    }
    #endregion

    #region CommitteeMemberMgr
    public class CommitteeMemberMgr
    {

        #region GetCommitteeMemberList
        public static DataTable GetCommitteeMemberList()
        {
            return CommitteeMemberDB.GetCommitteeMemberList();
        }
        #endregion

        #region GetNextCommitteeMemberCode
        public static string GetNextCommitteeMemberCode()
        {
            return CommitteeMemberDB.GetNextCommitteeMemberCode();
        }
        #endregion

        #region GetCommitteeMemberByCommitteeId
        public static DataTable GetCommitteeMemberByCommitteeId(int CommitteeId, int MeetingId)
        {
            return CommitteeMemberDB.GetCommitteeMemberByCommitteeId(CommitteeId, MeetingId);
        }
        #endregion

        #region GetCommitteeMemberByMeetingId
        public static DataTable GetCommitteeMemberByMeetingId(int MeetingId)
        {
            return CommitteeMemberDB.GetCommitteeMemberByMeetingId(MeetingId);
        }
        #endregion

        #region GetPresentCommitteeMemberByCommitteeId
        public static DataTable GetPresentCommitteeMemberByCommitteeId(int CommitteeId, int MeetingId)
        {
            return CommitteeMemberDB.GetPresentCommitteeMemberByCommitteeId(CommitteeId, MeetingId);
        }
        #endregion

        #region GetSittingFeesApplicable
        public static DataTable GetSittingFeesApplicable(int MeetingId, int CommitteeId)
        {
            return CommitteeMemberDB.GetSittingFeesApplicable(MeetingId, CommitteeId);
        }
        #endregion

        #region GetCommitteeMemberByCommitteeMemberId
        public static DataTable GetCommitteeMemberByCommitteeMemberId(int CommitteeMemberId)
        {
            return CommitteeMemberDB.GetCommitteeMemberByCommitteeMemberId(CommitteeMemberId);
        }
        #endregion

        #region AddEditCommitteeMember
        public int AddEditCommitteeMember(CommitteeMemberBAL CommitteeMemberBAL)
        {
            CommitteeMemberDAL CommitteeMemberDAL = new CommitteeMemberDAL();
            CommitteeMemberDAL.Code = CommitteeMemberBAL.Code;
            CommitteeMemberDAL.CommitteeMemberId = CommitteeMemberBAL.CommitteeMemberId;
            CommitteeMemberDAL.CommitteeId = CommitteeMemberBAL.CommitteeId;
            CommitteeMemberDAL.MemberId = CommitteeMemberBAL.MemberId;
            CommitteeMemberDAL.MemberTypeId = CommitteeMemberBAL.MemberTypeId;
            CommitteeMemberDAL.AppointmentDate = CommitteeMemberBAL.AppointmentDate;
            CommitteeMemberDAL.CessationDate = CommitteeMemberBAL.CessationDate;
            CommitteeMemberDAL.IsFeeApplicable = CommitteeMemberBAL.IsFeeApplicable;
            CommitteeMemberDAL.ApplicableFee = CommitteeMemberBAL.ApplicableFee;
            CommitteeMemberDAL.CreatedOn = CommitteeMemberBAL.CreatedOn;
            CommitteeMemberDAL.CreatedBy = CommitteeMemberBAL.CreatedBy;
            CommitteeMemberDAL.UpdatedOn = CommitteeMemberBAL.UpdatedOn;
            CommitteeMemberDAL.UpdatedBy = CommitteeMemberBAL.UpdatedBy;

            return CommitteeMemberDB.AddEditCommitteeMember(CommitteeMemberDAL);
        }
        #endregion

        #region DeleteCommitteeMemberByCommitteeMemberId
        public static int DeleteCommitteeMemberByCommitteeMemberId(int CommitteeMemberId)
        {
            return CommitteeMemberDB.DeleteCommitteeMemberByCommitteeMemberId(CommitteeMemberId);
        }
        #endregion

    }
    #endregion

}
