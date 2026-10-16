using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;


namespace BMMSDAL
{
    #region MemberDAL
    public class MemberDAL
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

    #region MemberDALList
    public class MemberDALList : List<MemberDAL>
    {
        #region MemberDALList
        public MemberDALList()
        {

        }
        #endregion
    }
    #endregion

    #region MemberDB
    public class MemberDB
    {
        #region GetMemberList
        public static DataTable GetMemberList(int StatusId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@StatusId", StatusId);

            return CommonDB.GetDataTable("spr_GetMember", parameter); ;
        }
        #endregion

        #region GetUnTagMemberByCommitteeId
        public static DataTable GetUnTagMemberByCommitteeId(int CommitteeId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);

            return CommonDB.GetDataTable("spr_GetUnTagMemberByCommitteeId", parameter); ;
        }
        #endregion

        #region GetUnTagMemberByMeetingId
        public static DataTable GetUnTagMemberByMeetingId(int CommitteeId, int MeetingId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);
            parameter[1] = new SqlParameter("@MeetingId", MeetingId);

            return CommonDB.GetDataTable("spr_GetUnTagMemberByMeetingId", parameter); ;
        }
        #endregion

        #region GetNextMemberCode
        public static string GetNextMemberCode()
        {
            DataTable dt = new DataTable();
            dt = CommonDB.GetDataTable("spr_GetNextMemberCode", null);

            return dt.Rows[0]["NextMemberCode"].ToString();
        }
        #endregion

        #region GetMemberByMemberId
        public static MemberDAL GetMemberByMemberId(int MemberId)
        {
            DataTable dt = new DataTable();

            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MemberId", MemberId);

            dt = CommonDB.GetDataTable("spr_GetMemberByMemberId", parameter);

            MemberDAL MemberDAL = new MemberDAL();
            MemberDAL.MemberId = Convert.ToInt16(dt.Rows[0]["MemberId"].ToString());
            MemberDAL.MemberCode = dt.Rows[0]["MemberCode"].ToString();
            MemberDAL.MemberName = dt.Rows[0]["MemberName"].ToString();
            MemberDAL.SexId = Convert.ToInt16(dt.Rows[0]["SexId"].ToString());
            MemberDAL.DesignationId = Convert.ToInt16(dt.Rows[0]["DesignationId"].ToString());
            MemberDAL.DOB = dt.Rows[0]["DOB"].ToString();
            MemberDAL.Address1 = dt.Rows[0]["Address1"].ToString();
            MemberDAL.Address2 = dt.Rows[0]["Address2"].ToString();
            MemberDAL.Address3 = dt.Rows[0]["Address3"].ToString();
            MemberDAL.CityName = dt.Rows[0]["CityName"].ToString();
            MemberDAL.State_Id = Convert.ToInt16(dt.Rows[0]["State_Id"].ToString());
            MemberDAL.PinCode = dt.Rows[0]["PinCode"].ToString();
            MemberDAL.DOJ = dt.Rows[0]["DOJ"].ToString();
            MemberDAL.EmailId = dt.Rows[0]["EmailId"].ToString();
            MemberDAL.DinNo = dt.Rows[0]["DinNo"].ToString();
            MemberDAL.PhotoPath = dt.Rows[0]["PhotoPath"].ToString();
            MemberDAL.ResumePath = dt.Rows[0]["ResumePath"].ToString();
            MemberDAL.RelievingDate = dt.Rows[0]["RelievingDate"].ToString();
            MemberDAL.StatusId = Convert.ToInt16(dt.Rows[0]["StatusId"].ToString());

            return MemberDAL;
        }
        #endregion

        #region GetMemberDTbyMemberId
        public static DataTable GetMemberDTbyMemberId(int MemberId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MemberId", MemberId);

            return CommonDB.GetDataTable("spr_GetMemberByMemberId", parameter); ;
        }
        #endregion

        #region GetMemberByMemberType
        public static DataTable GetMemberByMemberType(int MemberTypeId, int CommitteeId, int MeetingId)
        {
            SqlParameter[] parameter = new SqlParameter[3];
            parameter[0] = new SqlParameter("@MemberTypeId", MemberTypeId);
            parameter[1] = new SqlParameter("@CommitteeId", CommitteeId);
            parameter[2] = new SqlParameter("@MeetingId", MeetingId);

            return CommonDB.GetDataTable("spr_GetMemberByMemberType", parameter); ;
        }
        #endregion

        #region AddEditMember
        public static int AddEditMember(MemberDAL MemberDAL)
        {
            SqlParameter[] parameter = new SqlParameter[24];
            parameter[0] = new SqlParameter("@Code", MemberDAL.Code);
            parameter[1] = new SqlParameter("@MemberId", MemberDAL.MemberId);
            parameter[2] = new SqlParameter("@MemberCode", MemberDAL.MemberCode);
            parameter[3] = new SqlParameter("@MemberName", MemberDAL.MemberName);
            parameter[4] = new SqlParameter("@SexId", MemberDAL.SexId);
            parameter[5] = new SqlParameter("@DesignationId", MemberDAL.DesignationId);
            parameter[6] = new SqlParameter("@DOB", MemberDAL.DOB);
            parameter[7] = new SqlParameter("@Address1", MemberDAL.Address1);
            parameter[8] = new SqlParameter("@Address2", MemberDAL.Address2);
            parameter[9] = new SqlParameter("@Address3", MemberDAL.Address3);
            parameter[10] = new SqlParameter("@CityName", MemberDAL.CityName);
            parameter[11] = new SqlParameter("@State_Id", MemberDAL.State_Id);
            parameter[12] = new SqlParameter("@PinCode", MemberDAL.PinCode);
            parameter[13] = new SqlParameter("@DOJ", MemberDAL.DOJ);
            parameter[14] = new SqlParameter("@EmailId", MemberDAL.EmailId);
            parameter[15] = new SqlParameter("@DinNo", MemberDAL.DinNo);
            parameter[16] = new SqlParameter("@PhotoPath", MemberDAL.PhotoPath);
            parameter[17] = new SqlParameter("@ResumePath", MemberDAL.ResumePath);
            parameter[18] = new SqlParameter("@RelievingDate", MemberDAL.RelievingDate);
            parameter[19] = new SqlParameter("@StatusId", MemberDAL.StatusId);
            parameter[20] = new SqlParameter("@CreatedOn", MemberDAL.CreatedOn);
            parameter[21] = new SqlParameter("@CreatedBy", MemberDAL.CreatedBy);
            parameter[22] = new SqlParameter("@UpdatedOn", MemberDAL.UpdatedOn);
            parameter[23] = new SqlParameter("@UpdatedBy", MemberDAL.UpdatedBy);

            return CommonDB.ExecuteProcedure("spr_AddEditMember", parameter);
        }
        #endregion

        #region DeleteMemberByMemberId
        public static int DeleteMemberByMemberId(int MemberId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MemberId", MemberId);

            DataTable dtResult = new DataTable();
            dtResult = CommonDB.GetDataTable("spr_DeleteMemberByMemberId", parameter);

            return Convert.ToInt16(dtResult.Rows[0]["Result"].ToString());
        }
        #endregion
    }
    #endregion

}
