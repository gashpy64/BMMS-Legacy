using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region MemberBAL
    public class MemberBAL
    {
        #region Properties

        private string _Code;
        private int _MemberId;
        private string _MemberCode;
        private string _MemberName;
        private int _SexId;
        private int _DesignationId;
        private string _DOB;
        private string _Address1;
        private string _Address2;
        private string _Address3;
        private string _CityName;
        private int _State_Id;
        private string _PinCode;
        private string _DOJ;
        private string _RelievingDate;
        private string _EmailId;
        private string _DinNo;
        private string _PhotoPath;
        private string _ResumePath;
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
        public int MemberId
        {
            get { return _MemberId; }
            set { _MemberId = value; }
        }
        public string MemberCode
        {
            get { return _MemberCode; }
            set { _MemberCode = value; }
        }
        public string MemberName
        {
            get { return _MemberName; }
            set { _MemberName = value; }
        }
        public int SexId
        {
            get { return _SexId; }
            set { _SexId = value; }
        }
        public int DesignationId
        {
            get { return _DesignationId; }
            set { _DesignationId = value; }
        }
        public string DOB
        {
            get { return _DOB; }
            set { _DOB = value; }
        }
        public string Address1
        {
            get { return _Address1; }
            set { _Address1 = value; }
        }
        public string Address2
        {
            get { return _Address2; }
            set { _Address2 = value; }
        }
        public string Address3
        {
            get { return _Address3; }
            set { _Address3 = value; }
        }
        public string CityName
        {
            get { return _CityName; }
            set { _CityName = value; }
        }
        public int State_Id
        {
            get { return _State_Id; }
            set { _State_Id = value; }
        }
        public string PinCode
        {
            get { return _PinCode; }
            set { _PinCode = value; }
        }
        public string DOJ
        {
            get { return _DOJ; }
            set { _DOJ = value; }
        }
        public string RelievingDate
        {
            get { return _RelievingDate; }
            set { _RelievingDate = value; }
        }
        public string EmailId
        {
            get { return _EmailId; }
            set { _EmailId = value; }
        }
        public string DinNo
        {
            get { return _DinNo; }
            set { _DinNo = value; }
        }
        public string PhotoPath
        {
            get { return _PhotoPath; }
            set { _PhotoPath = value; }
        }
        public string ResumePath
        {
            get { return _ResumePath; }
            set { _ResumePath = value; }
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

    #region MemberBALList
    public class MemberBALList : List<MemberBAL>
    {
        #region public MemberBALList()
        public MemberBALList()
        {

        }
        #endregion
    }
    #endregion

    #region MemberMgr
    public class MemberMgr
    {
        #region GetMemberList
        public static DataTable GetMemberList(int StatusId)
        {
            return MemberDB.GetMemberList(StatusId);
        }
        #endregion

        #region GetUnTagMemberByCommitteeId
        public static DataTable GetUnTagMemberByCommitteeId(int CommitteeId)
        {
            return MemberDB.GetUnTagMemberByCommitteeId(CommitteeId);
        }
        #endregion

        #region GetUnTagMemberByMeetingId
        public static DataTable GetUnTagMemberByMeetingId(int CommitteeId, int MeetingId)
        {
            return MemberDB.GetUnTagMemberByMeetingId(CommitteeId, MeetingId);
        }
        #endregion

        #region GetNextMemberCode
        public static string GetNextMemberCode()
        {
            return MemberDB.GetNextMemberCode();
        }
        #endregion

        #region GetMemberByMemberId
        public static MemberBAL GetMemberByMemberId(int MemberId)
        {
            MemberDAL MemberDAL = new MemberDAL();
            MemberDAL = MemberDB.GetMemberByMemberId(MemberId);

            MemberBAL MemberBAL = new MemberBAL();
            MemberBAL.MemberId = MemberDAL.MemberId;
            MemberBAL.MemberCode = MemberDAL.MemberCode;
            MemberBAL.MemberName = MemberDAL.MemberName;
            MemberBAL.SexId = MemberDAL.SexId;
            MemberBAL.DesignationId = MemberDAL.DesignationId;
            MemberBAL.DOB = MemberDAL.DOB;
            MemberBAL.Address1 = MemberDAL.Address1;
            MemberBAL.Address2 = MemberDAL.Address2;
            MemberBAL.Address3 = MemberDAL.Address3;
            MemberBAL.CityName = MemberDAL.CityName;
            MemberBAL.State_Id = MemberDAL.State_Id;
            MemberBAL.PinCode = MemberDAL.PinCode;
            MemberBAL.DOJ = MemberDAL.DOJ;
            MemberBAL.EmailId = MemberDAL.EmailId;
            MemberBAL.DinNo = MemberDAL.DinNo;
            MemberBAL.PhotoPath = MemberDAL.PhotoPath;
            MemberBAL.ResumePath = MemberDAL.ResumePath;
            MemberBAL.RelievingDate = MemberDAL.RelievingDate;
            MemberBAL.StatusId = MemberDAL.StatusId;

            return MemberBAL;
        }
        #endregion

        #region GetMemberDTbyMemberId
        public static DataTable GetMemberDTbyMemberId(int MemberId)
        {
            return MemberDB.GetMemberDTbyMemberId(MemberId);
        }
        #endregion

        #region GetMemberByMemberType
        public static DataTable GetMemberByMemberType(int MemberTypeId, int CommitteeId, int MeetingId)
        {
            return MemberDB.GetMemberByMemberType(MemberTypeId, CommitteeId, MeetingId);
        }
        #endregion

        #region AddEditMember
        public int AddEditMember(MemberBAL MemberBAL)
        {
            MemberDAL MemberDAL = new MemberDAL();
            MemberDAL.Code = MemberBAL.Code;
            MemberDAL.MemberId = MemberBAL.MemberId;
            MemberDAL.MemberCode = MemberBAL.MemberCode;
            MemberDAL.MemberName = MemberBAL.MemberName;
            MemberDAL.SexId = MemberBAL.SexId;
            MemberDAL.DesignationId = MemberBAL.DesignationId;
            MemberDAL.DOB = MemberBAL.DOB;
            MemberDAL.Address1 = MemberBAL.Address1;
            MemberDAL.Address2 = MemberBAL.Address2;
            MemberDAL.Address3 = MemberBAL.Address3;
            MemberDAL.CityName = MemberBAL.CityName;
            MemberDAL.State_Id = MemberBAL.State_Id;
            MemberDAL.PinCode = MemberBAL.PinCode;
            MemberDAL.DOJ = MemberBAL.DOJ;
            MemberDAL.EmailId = MemberBAL.EmailId;
            MemberDAL.DinNo = MemberBAL.DinNo;
            MemberDAL.PhotoPath = MemberBAL.PhotoPath;
            MemberDAL.ResumePath = MemberBAL.ResumePath;
            MemberDAL.RelievingDate = MemberBAL.RelievingDate;
            MemberDAL.StatusId = MemberBAL.StatusId;
            MemberDAL.CreatedOn = MemberBAL.CreatedOn;
            MemberDAL.CreatedBy = MemberBAL.CreatedBy;
            MemberDAL.UpdatedOn = MemberBAL.UpdatedOn;
            MemberDAL.UpdatedBy = MemberBAL.UpdatedBy;

            return MemberDB.AddEditMember(MemberDAL);
        }
        #endregion

        #region DeleteMemberByMemberId
        public static int DeleteMemberByMemberId(int MemberId)
        {
            return MemberDB.DeleteMemberByMemberId(MemberId);
        }
        #endregion

    }
    #endregion

}
