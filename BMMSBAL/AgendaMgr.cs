using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region AgendaBAL
    public class AgendaBAL
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

    #region AgendaBALList
    public class AgendaBALList : List<AgendaBAL>
    {
        #region public AgendaBALList()
        public AgendaBALList()
        {

        }
        #endregion
    }
    #endregion

    #region AgendaMgr
    public class AgendaMgr
    {

        #region GetAgenda
        public static DataTable GetAgenda()
        {
            return AgendaDB.GetAgenda();
        }
        #endregion

        #region GetAgendaByMeetingId
        public static DataTable GetAgendaByMeetingId(int MeetingId)
        {
            return AgendaDB.GetAgendaByMeetingId(MeetingId);
        }
        #endregion

        #region GetAgendaByMeetingIdDeptId
        public static DataTable GetAgendaByMeetingIdDeptId(int MeetingId, int UserId)
        {
            return AgendaDB.GetAgendaByMeetingIdDeptId(MeetingId, UserId);
        }
        #endregion

        #region GetAgendaApprovedByMeetingId
        public static DataTable GetAgendaApprovedByMeetingId(int MeetingId, int DepartmentId)
        {
            return AgendaDB.GetAgendaApprovedByMeetingId(MeetingId, DepartmentId);
        }
        #endregion


        #region GetAgendaBySubjectNo
        public static DataTable GetAgendaBySubjectNo(int MeetingId, int DepartmentId)
        {
            return AgendaDB.GetAgendaBySubjectNo(MeetingId, DepartmentId);
        }
        #endregion

        #region GetNextAgendaNo
        public static string GetNextAgendaNo(int CommitteeId, int MeetingId)
        {
            return AgendaDB.GetNextAgendaNo(CommitteeId, MeetingId);
        }
        #endregion

        #region GetAgendaByAgendaId
        public static DataTable GetAgendaByAgendaId(int AgendaId)
        {
            return AgendaDB.GetAgendaByAgendaId(AgendaId);
        }
        #endregion

        #region AddEditAgenda
        public int AddEditAgenda(AgendaBAL agendaBAL)
        {
            AgendaDAL agendaDAL = new AgendaDAL();
            agendaDAL.Code = agendaBAL.Code;
            agendaDAL.AgendaId = agendaBAL.AgendaId;
            agendaDAL.AgendaNo = agendaBAL.AgendaNo;
            agendaDAL.CommitteeId = agendaBAL.CommitteeId;
            agendaDAL.MeetingId = agendaBAL.MeetingId;
            agendaDAL.DepartmentId = agendaBAL.DepartmentId;
            agendaDAL.SubjectTypeId = agendaBAL.SubjectTypeId;
            agendaDAL.ShortText = agendaBAL.ShortText;
            agendaDAL.AgendaType = agendaBAL.AgendaType;
            agendaDAL.AgendaText = agendaBAL.AgendaText;
            agendaDAL.AgendaTextPath = agendaBAL.AgendaTextPath;
            agendaDAL.ProposedResolution = agendaBAL.ProposedResolution;
            agendaDAL.FilePath = agendaBAL.FilePath;
            agendaDAL.MgrComments = agendaBAL.MgrComments;
            agendaDAL.ControllerComments = agendaBAL.ControllerComments;
            agendaDAL.CurrentStatus = agendaBAL.CurrentStatus;
            agendaDAL.CreatedOn = agendaBAL.CreatedOn;
            agendaDAL.CreatedBy = agendaBAL.CreatedBy;
            agendaDAL.UpdatedOn = agendaBAL.UpdatedOn;
            agendaDAL.UpdatedBy = agendaBAL.UpdatedBy;
            agendaDAL.SubjectNo = agendaBAL.SubjectNo;

            return AgendaDB.AddEditAgenda(agendaDAL);
        }
        #endregion

        #region AddEditAgendaByController
        public int AddEditAgendaByController(AgendaBAL agendaBAL)
        {
            AgendaDAL agendaDAL = new AgendaDAL();
            agendaDAL.Code = agendaBAL.Code;
            agendaDAL.AgendaId = agendaBAL.AgendaId;
            agendaDAL.AgendaNo = agendaBAL.AgendaNo;
            agendaDAL.CommitteeId = agendaBAL.CommitteeId;
            agendaDAL.MeetingId = agendaBAL.MeetingId;
            agendaDAL.DepartmentId = agendaBAL.DepartmentId;
            agendaDAL.SubjectTypeId = agendaBAL.SubjectTypeId;
            agendaDAL.ShortText = agendaBAL.ShortText;
            agendaDAL.AgendaType = agendaBAL.AgendaType;
            agendaDAL.AgendaText = agendaBAL.AgendaText;
            agendaDAL.AgendaTextPath = agendaBAL.AgendaTextPath;
            agendaDAL.ProposedResolution = agendaBAL.ProposedResolution;
            agendaDAL.FilePath = agendaBAL.FilePath;
            agendaDAL.MgrComments = agendaBAL.MgrComments;
            agendaDAL.ControllerComments = agendaBAL.ControllerComments;
            agendaDAL.CurrentStatus = agendaBAL.CurrentStatus;
            agendaDAL.CreatedOn = agendaBAL.CreatedOn;
            agendaDAL.CreatedBy = agendaBAL.CreatedBy;
            agendaDAL.UpdatedOn = agendaBAL.UpdatedOn;
            agendaDAL.UpdatedBy = agendaBAL.UpdatedBy;
            agendaDAL.SubjectNo = agendaBAL.SubjectNo;

            return AgendaDB.AddEditAgendaByController(agendaDAL);
        }
        #endregion

        #region AddEditAgendaByManager
        public int AddEditAgendaByManager(AgendaBAL agendaBAL)
        {
            AgendaDAL agendaDAL = new AgendaDAL();
            agendaDAL.Code = agendaBAL.Code;
            agendaDAL.AgendaId = agendaBAL.AgendaId;
            agendaDAL.AgendaNo = agendaBAL.AgendaNo;
            agendaDAL.CommitteeId = agendaBAL.CommitteeId;
            agendaDAL.MeetingId = agendaBAL.MeetingId;
            agendaDAL.DepartmentId = agendaBAL.DepartmentId;
            agendaDAL.SubjectTypeId = agendaBAL.SubjectTypeId;
            agendaDAL.ShortText = agendaBAL.ShortText;
            agendaDAL.AgendaType = agendaBAL.AgendaType;
            agendaDAL.AgendaText = agendaBAL.AgendaText;
            agendaDAL.AgendaTextPath = agendaBAL.AgendaTextPath;
            agendaDAL.ProposedResolution = agendaBAL.ProposedResolution;
            agendaDAL.FilePath = agendaBAL.FilePath;
            agendaDAL.MgrComments = agendaBAL.MgrComments;
            agendaDAL.ControllerComments = agendaBAL.ControllerComments;
            agendaDAL.CurrentStatus = agendaBAL.CurrentStatus;
            agendaDAL.CreatedOn = agendaBAL.CreatedOn;
            agendaDAL.CreatedBy = agendaBAL.CreatedBy;
            agendaDAL.UpdatedOn = agendaBAL.UpdatedOn;
            agendaDAL.UpdatedBy = agendaBAL.UpdatedBy;
            agendaDAL.SubjectNo = agendaBAL.SubjectNo;

            return AgendaDB.AddEditAgendaByManager(agendaDAL);
        }
        #endregion

        #region DeleteAgendaByAgendaId
        public static int DeleteAgendaByAgendaId(int AgendaId)
        {
            return AgendaDB.DeleteAgendaByAgendaId(AgendaId);
        }
        #endregion

        #region UpdateAgendaByAgendaId
        public static int UpdateAgendaByAgendaId(AgendaBAL agendaBAL)
        {
            AgendaDAL agendaDAL = new AgendaDAL();
            agendaDAL.AgendaId = agendaBAL.AgendaId;
            agendaDAL.ShortText = agendaBAL.ShortText;
            agendaDAL.ProposedResolution = agendaBAL.ProposedResolution;
            agendaDAL.MgrComments = agendaBAL.MgrComments;
            agendaDAL.ControllerComments = agendaBAL.ControllerComments;
            agendaDAL.MgrApprovedStatus = agendaBAL.MgrApprovedStatus;
            agendaDAL.ControllerApprovedStatus = agendaBAL.ControllerApprovedStatus;
            agendaDAL.UpdatedBy = agendaBAL.UpdatedBy;

            return AgendaDB.UpdateAgendaByAgendaId(agendaDAL);
            //return AgendaDB.UpdateAgendaByAgendaId(AgendaId, MgrComments, ControllerComments, MgrApprovedStatus, ControllerApprovedStatus, UpdatedBy);
        }
        #endregion

        #region UpdateAgendaShortText
        public static int UpdateAgendaShortText(AgendaBAL agendaBAL)
        {
            AgendaDAL agendaDAL = new AgendaDAL();
            agendaDAL.AgendaId = agendaBAL.AgendaId;
            agendaDAL.ShortText = agendaBAL.ShortText;
            agendaDAL.UpdatedBy = agendaBAL.UpdatedBy;

            return AgendaDB.UpdateAgendaShortText(agendaDAL);
        }
        #endregion

        #region AgendaFinalizeByMeetingId
        public static int AgendaFinalizeByMeetingId(int MeetingId)
        {
            return AgendaDB.AgendaFinalizeByMeetingId(MeetingId);
        }
        #endregion

        #region GenerateSubjectNoByMeetingId
        public static int GenerateSubjectNoByMeetingId(int MeetingId, int AgendaId)
        {
            return AgendaDB.GenerateSubjectNoByMeetingId(MeetingId, AgendaId);
        }
        #endregion

        #region UpdateSubjectNoByAgendaId
        public static int UpdateSubjectNoByAgendaId(int AgendaId, int SubjectNo)
        {
            return AgendaDB.UpdateSubjectNoByAgendaId(AgendaId, SubjectNo);
        }
        #endregion


        #region MinutesFinalizeByMeetingId
        public static int MinutesFinalizeByMeetingId(int MeetingId, int UserId)
        {
            return AgendaDB.MinutesFinalizeByMeetingId(MeetingId, UserId);
        }
        #endregion

        #region MinutesConfirmByMeetingId
        public static int MinutesConfirmByMeetingId(int MeetingId, int UserId)
        {
            return AgendaDB.MinutesConfirmByMeetingId(MeetingId, UserId);
        }
        #endregion

        #region CheckAgendaFinalizeByMeetingId
        public static DataTable CheckAgendaFinalizeByMeetingId(int MeetingId)
        {
            return AgendaDB.CheckAgendaFinalizeByMeetingId(MeetingId);
        }
        #endregion 

        #region CheckAgendaByMeetingId
        public static DataTable CheckAgendaByMeetingId(int MeetingId)
        {
            return AgendaDB.CheckAgendaByMeetingId(MeetingId);
        }
        #endregion 

        #region CheckMinutesByMeetingId
        public static DataTable CheckMinutesByMeetingId(int MeetingId)
        {
            return AgendaDB.CheckMinutesByMeetingId(MeetingId);
        }
        #endregion 

        #region CheckAgendaApprovedByMeetingId
        public static DataTable CheckAgendaApprovedByMeetingId(int MeetingId)
        {
            return AgendaDB.CheckAgendaApprovedByMeetingId(MeetingId);
        }
        #endregion 
 
        #region CheckSubjectNoByMeetingId
        public static DataTable CheckSubjectNoByMeetingId(int MeetingId)
        {
            return AgendaDB.CheckSubjectNoByMeetingId(MeetingId);
        }
        #endregion 
      
        #region CheckMinutesFinalizeByMeetingId
        public static DataTable CheckMinutesFinalizeByMeetingId(int MeetingId)
        {
            return AgendaDB.CheckMinutesFinalizeByMeetingId(MeetingId);
        }
        #endregion 
 
        #region CheckMinutesConfirmByMeetingId
        public static DataTable CheckMinutesConfirmByMeetingId(int MeetingId)
        {
            return AgendaDB.CheckMinutesConfirmByMeetingId(MeetingId);
        }
        #endregion 
    }
    #endregion

}
