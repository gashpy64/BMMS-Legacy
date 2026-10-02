using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;


namespace BMMSDAL
{
    #region AgendaDAL
    public class AgendaDAL
    {
        #region Properties

        private string _Code;
        private int _AgendaId;
        private string _AgendaNo;
        private string _SubjectNo;
        private int _CommitteeId;
        private int _MeetingId;
        private int _DepartmentId;
        private int _SubjectTypeId;
        private string _ShortText;
        private string _AgendaType;
        private string _AgendaText;
        private string _AgendaTextPath;
        private string _ProposedResolution;
        private string _FilePath;
        private string _MgrComments;
        private string _ControllerComments;
        private string _MgrApprovedStatus;
        private string _ControllerApprovedStatus;
        private string _CurrentStatus;
        private int _MgrApprovedBy;
        private DateTime _MgrApprovedDate;

        private DateTime _CreatedOn;
        private int _CreatedBy;
        private DateTime _UpdatedOn;
        private int _UpdatedBy;

        public string Code
        {
            get { return _Code; }
            set { _Code = value; }
        }
        public int AgendaId
        {
            get { return _AgendaId; }
            set { _AgendaId = value; }
        }
        public string AgendaNo
        {
            get { return _AgendaNo; }
            set { _AgendaNo = value; }
        }

        public string SubjectNo
        {
            get { return _SubjectNo; }
            set { _SubjectNo = value; }
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
        public int DepartmentId
        {
            get { return _DepartmentId; }
            set { _DepartmentId = value; }
        }
        public int SubjectTypeId
        {
            get { return _SubjectTypeId; }
            set { _SubjectTypeId = value; }
        }
        public string ShortText
        {
            get { return _ShortText; }
            set { _ShortText = value; }
        }
        public string AgendaType
        {
            get { return _AgendaType; }
            set { _AgendaType = value; }
        }
        public string AgendaText
        {
            get { return _AgendaText; }
            set { _AgendaText = value; }
        }
        public string AgendaTextPath
        {
            get { return _AgendaTextPath; }
            set { _AgendaTextPath = value; }
        }
        public string ProposedResolution
        {
            get { return _ProposedResolution; }
            set { _ProposedResolution = value; }
        }
        public string FilePath
        {
            get { return _FilePath; }
            set { _FilePath = value; }
        }
        public string MgrComments
        {
            get { return _MgrComments; }
            set { _MgrComments = value; }
        }
        public string ControllerComments
        {
            get { return _ControllerComments; }
            set { _ControllerComments = value; }
        }
        public string MgrApprovedStatus
        {
            get { return _MgrApprovedStatus; }
            set { _MgrApprovedStatus = value; }
        }
        public string ControllerApprovedStatus
        {
            get { return _ControllerApprovedStatus; }
            set { _ControllerApprovedStatus = value; }
        }
        public string CurrentStatus
        {
            get { return _CurrentStatus; }
            set { _CurrentStatus = value; }
        }
        public int MgrApprovedBy
        {
            get { return _MgrApprovedBy; }
            set { _MgrApprovedBy = value; }
        }
        public DateTime MgrApprovedDate
        {
            get { return _MgrApprovedDate; }
            set { _MgrApprovedDate = value; }
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

    #region AgendaDALList
    public class AgendaDALList : List<AgendaDAL>
    {
        #region AgendaDALList
        public AgendaDALList()
        {

        }
        #endregion
    }
    #endregion

    #region AgendaDB
    public class AgendaDB
    {

        #region GetAgenda
        public static DataTable GetAgenda()
        {
            return CommonDB.GetDataTable("spr_GetAgenda", null); ;
        }
        #endregion

        #region GetAgendaByMeetingId
        public static DataTable GetAgendaByMeetingId(int MeetingId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);

            return CommonDB.GetDataTable("spr_GetAgendaByMeetingId", parameter); ;
        }
        #endregion

        #region GetAgendaByMeetingIdDeptId
        public static DataTable GetAgendaByMeetingIdDeptId(int MeetingId, int UserId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);
            parameter[1] = new SqlParameter("@UserId", UserId);

            return CommonDB.GetDataTable("spr_GetAgendaByMeetingIdDeptId", parameter); ;
        }
        #endregion


        #region GetAgendaApprovedByMeetingId
        public static DataTable GetAgendaApprovedByMeetingId(int MeetingId, int DepartmentId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);
            parameter[1] = new SqlParameter("@DepartmentId", DepartmentId);

            return CommonDB.GetDataTable("spr_GetAgendaApprovedByMeetingId", parameter); ;
        }
        #endregion

        #region GetAgendaBySubjectNo
        public static DataTable GetAgendaBySubjectNo(int MeetingId, int DepartmentId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);
            parameter[1] = new SqlParameter("@DepartmentId", DepartmentId);

            return CommonDB.GetDataTable("spr_GetAgendaBySubjectNo", parameter); ;
        }
        #endregion

        #region GetNextAgendaNo
        public static string GetNextAgendaNo(int CommitteeId, int MeetingId)
        {
            DataTable dt = new DataTable();

            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);
            parameter[1] = new SqlParameter("@MeetingId", MeetingId);

            dt = CommonDB.GetDataTable("spr_GetNextAgendaNo", parameter);

            return dt.Rows[0]["NextAgendaNo"].ToString();
        }
        #endregion

        #region GetAgendaByAgendaId
        public static DataTable GetAgendaByAgendaId(int AgendaId)
        {
            DataTable dt = new DataTable();

            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@AgendaId", AgendaId);

            return CommonDB.GetDataTable("spr_GetAgendaByAgendaId", parameter);

        }
        #endregion

        #region AddEditAgenda
        public static int AddEditAgenda(AgendaDAL AgendaDAL)
        {
            SqlParameter[] parameter = new SqlParameter[21];
            parameter[0] = new SqlParameter("@Code", AgendaDAL.Code);
            parameter[1] = new SqlParameter("@AgendaId", AgendaDAL.AgendaId);
            parameter[2] = new SqlParameter("@AgendaNo", AgendaDAL.AgendaNo);
            parameter[3] = new SqlParameter("@CommitteeId", AgendaDAL.CommitteeId);
            parameter[4] = new SqlParameter("@MeetingId", AgendaDAL.MeetingId);
            parameter[5] = new SqlParameter("@DepartmentId", AgendaDAL.DepartmentId);
            parameter[6] = new SqlParameter("@SubjectTypeId", AgendaDAL.SubjectTypeId);
            parameter[7] = new SqlParameter("@ShortText", AgendaDAL.ShortText);
            parameter[8] = new SqlParameter("@AgendaType", AgendaDAL.AgendaType);
            parameter[9] = new SqlParameter("@AgendaText", AgendaDAL.AgendaText);
            parameter[10] = new SqlParameter("@AgendaTextPath", AgendaDAL.AgendaTextPath);
            parameter[11] = new SqlParameter("@ProposedResolution", AgendaDAL.ProposedResolution);
            parameter[12] = new SqlParameter("@FilePath", AgendaDAL.FilePath);
            parameter[13] = new SqlParameter("@MgrComments", AgendaDAL.MgrComments);
            parameter[14] = new SqlParameter("@ControllerComments", AgendaDAL.ControllerComments);
            parameter[15] = new SqlParameter("@CurrentStatus", AgendaDAL.CurrentStatus);
            parameter[16] = new SqlParameter("@CreatedOn", AgendaDAL.CreatedOn);
            parameter[17] = new SqlParameter("@CreatedBy", AgendaDAL.CreatedBy);
            parameter[18] = new SqlParameter("@UpdatedOn", AgendaDAL.UpdatedOn);
            parameter[19] = new SqlParameter("@UpdatedBy", AgendaDAL.UpdatedBy);
            parameter[20] = new SqlParameter("@SubjectNo", AgendaDAL.SubjectNo);

            return CommonDB.ExecuteProcedure("spr_AddEditAgenda", parameter);
        }
        #endregion

        #region AddEditAgendaByController
        public static int AddEditAgendaByController(AgendaDAL AgendaDAL)
        {
            SqlParameter[] parameter = new SqlParameter[21];
            parameter[0] = new SqlParameter("@Code", AgendaDAL.Code);
            parameter[1] = new SqlParameter("@AgendaId", AgendaDAL.AgendaId);
            parameter[2] = new SqlParameter("@AgendaNo", AgendaDAL.AgendaNo);
            parameter[3] = new SqlParameter("@CommitteeId", AgendaDAL.CommitteeId);
            parameter[4] = new SqlParameter("@MeetingId", AgendaDAL.MeetingId);
            parameter[5] = new SqlParameter("@DepartmentId", AgendaDAL.DepartmentId);
            parameter[6] = new SqlParameter("@SubjectTypeId", AgendaDAL.SubjectTypeId);
            parameter[7] = new SqlParameter("@ShortText", AgendaDAL.ShortText);
            parameter[8] = new SqlParameter("@AgendaType", AgendaDAL.AgendaType);
            parameter[9] = new SqlParameter("@AgendaText", AgendaDAL.AgendaText);
            parameter[10] = new SqlParameter("@AgendaTextPath", AgendaDAL.AgendaTextPath);
            parameter[11] = new SqlParameter("@ProposedResolution", AgendaDAL.ProposedResolution);
            parameter[12] = new SqlParameter("@FilePath", AgendaDAL.FilePath);
            parameter[13] = new SqlParameter("@MgrComments", AgendaDAL.MgrComments);
            parameter[14] = new SqlParameter("@ControllerComments", AgendaDAL.ControllerComments);
            parameter[15] = new SqlParameter("@CurrentStatus", AgendaDAL.CurrentStatus);
            parameter[16] = new SqlParameter("@CreatedOn", AgendaDAL.CreatedOn);
            parameter[17] = new SqlParameter("@CreatedBy", AgendaDAL.CreatedBy);
            parameter[18] = new SqlParameter("@UpdatedOn", AgendaDAL.UpdatedOn);
            parameter[19] = new SqlParameter("@UpdatedBy", AgendaDAL.UpdatedBy);
            parameter[20] = new SqlParameter("@SubjectNo", AgendaDAL.SubjectNo);

            return CommonDB.ExecuteProcedure("spr_AddEditAgendaByController", parameter);
        }
        #endregion

        #region AddEditAgendaByManager
        public static int AddEditAgendaByManager(AgendaDAL AgendaDAL)
        {
            SqlParameter[] parameter = new SqlParameter[21];
            parameter[0] = new SqlParameter("@Code", AgendaDAL.Code);
            parameter[1] = new SqlParameter("@AgendaId", AgendaDAL.AgendaId);
            parameter[2] = new SqlParameter("@AgendaNo", AgendaDAL.AgendaNo);
            parameter[3] = new SqlParameter("@CommitteeId", AgendaDAL.CommitteeId);
            parameter[4] = new SqlParameter("@MeetingId", AgendaDAL.MeetingId);
            parameter[5] = new SqlParameter("@DepartmentId", AgendaDAL.DepartmentId);
            parameter[6] = new SqlParameter("@SubjectTypeId", AgendaDAL.SubjectTypeId);
            parameter[7] = new SqlParameter("@ShortText", AgendaDAL.ShortText);
            parameter[8] = new SqlParameter("@AgendaType", AgendaDAL.AgendaType);
            parameter[9] = new SqlParameter("@AgendaText", AgendaDAL.AgendaText);
            parameter[10] = new SqlParameter("@AgendaTextPath", AgendaDAL.AgendaTextPath);
            parameter[11] = new SqlParameter("@ProposedResolution", AgendaDAL.ProposedResolution);
            parameter[12] = new SqlParameter("@FilePath", AgendaDAL.FilePath);
            parameter[13] = new SqlParameter("@MgrComments", AgendaDAL.MgrComments);
            parameter[14] = new SqlParameter("@ControllerComments", AgendaDAL.ControllerComments);
            parameter[15] = new SqlParameter("@CurrentStatus", AgendaDAL.CurrentStatus);
            parameter[16] = new SqlParameter("@CreatedOn", AgendaDAL.CreatedOn);
            parameter[17] = new SqlParameter("@CreatedBy", AgendaDAL.CreatedBy);
            parameter[18] = new SqlParameter("@UpdatedOn", AgendaDAL.UpdatedOn);
            parameter[19] = new SqlParameter("@UpdatedBy", AgendaDAL.UpdatedBy);
            parameter[20] = new SqlParameter("@SubjectNo", AgendaDAL.SubjectNo);

            return CommonDB.ExecuteProcedure("spr_AddEditAgendaByManager", parameter);
        }
        #endregion

        #region DeleteAgendaByAgendaId
        public static int DeleteAgendaByAgendaId(int AgendaId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@AgendaId", AgendaId);

            return CommonDB.ExecuteProcedure("spr_DeleteAgendaByAgendaId", parameter); ;
        }
        #endregion

        #region UpdateAgendaByAgendaId
        public static int UpdateAgendaByAgendaId(AgendaDAL AgendaDAL)  //int AgendaId, string MgrComments, string ControllerComments, string MgrApprovedStatus, string ControllerApprovedStatus, int UpdatedBy)
        {
            SqlParameter[] parameter = new SqlParameter[8];
            parameter[0] = new SqlParameter("@AgendaId", AgendaDAL.AgendaId);
            parameter[1] = new SqlParameter("@ShortText", AgendaDAL.ShortText);
            parameter[2] = new SqlParameter("@ProposedResolution", AgendaDAL.ProposedResolution);
            parameter[3] = new SqlParameter("@MgrComments", AgendaDAL.MgrComments);
            parameter[4] = new SqlParameter("@ControllerComments", AgendaDAL.ControllerComments);
            parameter[5] = new SqlParameter("@MgrApprovedStatus", AgendaDAL.MgrApprovedStatus);
            parameter[6] = new SqlParameter("@ControllerApprovedStatus", AgendaDAL.ControllerApprovedStatus);
            parameter[7] = new SqlParameter("@UpdatedBy", AgendaDAL.UpdatedBy);

            return CommonDB.ExecuteProcedure("spr_UpdateAgendaByAgendaId", parameter); ;
        }
        #endregion

        #region UpdateAgendaShortText
        public static int UpdateAgendaShortText(AgendaDAL AgendaDAL)
        {
            SqlParameter[] parameter = new SqlParameter[3];
            parameter[0] = new SqlParameter("@AgendaId", AgendaDAL.AgendaId);
            parameter[1] = new SqlParameter("@ShortText", AgendaDAL.ShortText);
            parameter[2] = new SqlParameter("@UpdatedBy", AgendaDAL.UpdatedBy);

            return CommonDB.ExecuteProcedure("spr_UpdateAgendaShortText", parameter);
        }
        #endregion

        #region AgendaFinalizeByMeetingId
        public static int AgendaFinalizeByMeetingId(int MeetingId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);

            return CommonDB.ExecuteProcedure("spr_AgendaFinalizeByMeetingId", parameter); ;
        }
        #endregion

        #region GenerateSubjectNoByMeetingId
        public static int GenerateSubjectNoByMeetingId(int MeetingId, int AgendaId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);
            parameter[1] = new SqlParameter("@AgendaId", AgendaId);

            return CommonDB.ExecuteProcedure("spr_GenerateSubjectNoByMeetingId", parameter); ;
        }
        #endregion

        #region UpdateSubjectNoByAgendaId
        public static int UpdateSubjectNoByAgendaId(int AgendaId, int SubjectNo)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@AgendaId", AgendaId);
            parameter[1] = new SqlParameter("@SubjectNo", SubjectNo);

            return CommonDB.ExecuteProcedure("spr_UpdateSubjectNoByAgendaId", parameter); ;
        }
        #endregion

        #region MinutesFinalizeByMeetingId
        public static int MinutesFinalizeByMeetingId(int MeetingId, int UserId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);
            parameter[1] = new SqlParameter("@UserId", UserId);

            return CommonDB.ExecuteProcedure("spr_MinutesFinalizeByMeetingId", parameter); ;
        }
        #endregion

        #region MinutesConfirmByMeetingId
        public static int MinutesConfirmByMeetingId(int MeetingId, int UserId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);
            parameter[1] = new SqlParameter("@UserId", UserId);

            return CommonDB.ExecuteProcedure("spr_MinutesConfirmByMeetingId", parameter); ;
        }
        #endregion

        #region CheckAgendaFinalizeByMeetingId
        public static DataTable CheckAgendaFinalizeByMeetingId(int MeetingId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);

            return CommonDB.GetDataTable("spr_CheckAgendaFinalizeByMeetingId", parameter); ;
        }
        #endregion

        #region CheckAgendaByMeetingId
        public static DataTable CheckAgendaByMeetingId(int MeetingId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);

            return CommonDB.GetDataTable("spr_CheckAgendaByMeetingId", parameter); ;
        }
        #endregion

        #region CheckMinutesByMeetingId
        public static DataTable CheckMinutesByMeetingId(int MeetingId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);

            return CommonDB.GetDataTable("spr_CheckMinutesByMeetingId", parameter); ;
        }
        #endregion

        #region CheckAgendaApprovedByMeetingId
        public static DataTable CheckAgendaApprovedByMeetingId(int MeetingId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);

            return CommonDB.GetDataTable("spr_CheckAgendaApprovedByMeetingId", parameter); ;
        }
        #endregion

        #region CheckSubjectNoByMeetingId
        public static DataTable CheckSubjectNoByMeetingId(int MeetingId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);

            return CommonDB.GetDataTable("spr_CheckSubjectNoByMeetingId", parameter); ;
        }
        #endregion

        #region CheckMinutesFinalizeByMeetingId
        public static DataTable CheckMinutesFinalizeByMeetingId(int MeetingId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);

            return CommonDB.GetDataTable("spr_CheckMinutesFinalizeByMeetingId", parameter); ;
        }
        #endregion

        #region CheckMinutesConfirmByMeetingId
        public static DataTable CheckMinutesConfirmByMeetingId(int MeetingId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);

            return CommonDB.GetDataTable("spr_CheckMinutesConfirmByMeetingId", parameter); ;
        }
        #endregion

    }
    #endregion

}
