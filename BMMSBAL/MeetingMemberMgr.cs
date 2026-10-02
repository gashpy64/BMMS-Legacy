using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region MeetingMemberBAL
    public class MeetingMemberBAL
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

    #region MeetingMemberBALList
    public class MeetingMemberBALList : List<MeetingMemberBAL>
    {
        #region public MeetingMemberBALList()
        public MeetingMemberBALList()
        {

        }
        #endregion
    }
    #endregion

    #region MeetingMemberMgr
    public class MeetingMemberMgr
    {

        #region GetNextMeetingMemberCode
        public static string GetNextMeetingMemberCode()
        {
            return MeetingMemberDB.GetNextMeetingMemberCode();
        }
        #endregion

        #region GetMeetingMemberByMeetingId
        public static DataTable GetMeetingMemberByMeetingId(int MeetingId)
        {
            return MeetingMemberDB.GetMeetingMemberByMeetingId(MeetingId);
        }
        #endregion

        #region GetMeetingMemberByMeetingIdMemberTypeId
        public static DataTable GetMeetingMemberByMeetingIdMemberTypeId(int MeetingId, int MemberTypeId)
        {
            return MeetingMemberDB.GetMeetingMemberByMeetingIdMemberTypeId(MeetingId, MemberTypeId);
        }
        #endregion

        #region GetMeetingMemberByMeetingMemberId
        public static DataTable GetMeetingMemberByMeetingMemberId(int MeetingMemberId)
        {
            return MeetingMemberDB.GetMeetingMemberByMeetingMemberId(MeetingMemberId);
        }
        #endregion

        #region AddEditMeetingMember
        public int AddEditMeetingMember(MeetingMemberBAL MeetingMemberBAL)
        {
            MeetingMemberDAL MeetingMemberDAL = new MeetingMemberDAL();
            MeetingMemberDAL.Code = MeetingMemberBAL.Code;
            MeetingMemberDAL.MeetingMemberId = MeetingMemberBAL.MeetingMemberId;
            MeetingMemberDAL.MeetingId = MeetingMemberBAL.MeetingId;
            MeetingMemberDAL.MemberId = MeetingMemberBAL.MemberId;
            MeetingMemberDAL.MemberTypeId = MeetingMemberBAL.MemberTypeId;
            MeetingMemberDAL.StatusId = MeetingMemberBAL.StatusId;
            MeetingMemberDAL.CreatedOn = MeetingMemberBAL.CreatedOn;
            MeetingMemberDAL.CreatedBy = MeetingMemberBAL.CreatedBy;
            MeetingMemberDAL.UpdatedOn = MeetingMemberBAL.UpdatedOn;
            MeetingMemberDAL.UpdatedBy = MeetingMemberBAL.UpdatedBy;

            return MeetingMemberDB.AddEditMeetingMember(MeetingMemberDAL);
        }
        #endregion

        #region DeleteMeetingMemberByMeetingMemberId
        public static int DeleteMeetingMemberByMeetingMemberId(int MeetingMemberId)
        {
            return MeetingMemberDB.DeleteMeetingMemberByMeetingMemberId(MeetingMemberId);
        }
        #endregion

    }
    #endregion

}
