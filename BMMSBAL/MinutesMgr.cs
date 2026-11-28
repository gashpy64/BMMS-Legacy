using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region MinutesBAL
    public class MinutesBAL
    {
        #region Properties

        private string _Code;
        private int _MinutesId;
        private int _DecisionTypeId;
        private DateTime? _DueDate;   // step UN6a: null = no due date (Followup only; BMMS-Fix-MinutesDueDate-Step38.sql)
        private string _Directions;
        private string _ActualResolution;
        private string _ShortText = string.Empty;
        private DateTime _CreatedOn;
        private int _CreatedBy;
        private DateTime _UpdatedOn;
        private int _UpdatedBy;

        public string Code
        {
            get { return _Code; }
            set { _Code = value; }
        }
        public int MinutesId
        {
            get { return _MinutesId; }
            set { _MinutesId = value; }
        }
        public int DecisionTypeId
        {
            get { return _DecisionTypeId; }
            set { _DecisionTypeId = value; }
        }
        public DateTime? DueDate
        {
            get { return _DueDate; }
            set { _DueDate = value; }
        }
        // Step UN6a1: send @DueDate with the save (Save minutes, when MinutesMgr.HasDueDateParameter() is true)
        public bool SendDueDate { get; set; }
        public string Directions
        {
            get { return _Directions; }
            set { _Directions = value; }
        }
        public string ActualResolution
        {
            get { return _ActualResolution; }
            set { _ActualResolution = value; }
        }
        public string ShortText
        {
            get { return _ShortText; }
            set { _ShortText = value; }
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

    #region MinutesBALList
    public class MinutesBALList : List<MinutesBAL>
    {
        #region public MinutesBALList()
        public MinutesBALList()
        {

        }
        #endregion
    }
    #endregion

    #region MinutesMgr
    public class MinutesMgr
    {

        #region GetMinutesByMeetingId
        public static DataTable GetMinutesByMeetingId(int MeetingId, int StatusId, int DepartmentId)
        {
            return MinutesDB.GetMinutesByMeetingId(MeetingId, StatusId, DepartmentId);
        }
        #endregion

        #region GetMinutesItemList
        // Step MF1: the read-only Minutes Items list of Finalize Minutes and Minutes Confirmation, from the rows of
        // spr_GetMinutesByMeetingId (View_Minute; all departments, as Update Minutes reads them). Columns AgendaNo,
        // SubjectNo, ShortText, Decision, ActualResolution, all plain text (the page encodes each cell once), in
        // Agenda No order. A minute not saved in Update Minutes (StatusId other than 1, the rule of
        // fn_WorkflowState.MinutesUpdated) shows "Not yet recorded" for Decision and Actual Resolution: its stored
        // values are the defaults of Agenda Finalize. A saved minute with nothing left after ToPlainText: "Not
        // recorded". Subject No empty or 0: "-". Total and NotSaved are counted from the same rows.
        public static MinutesItemList GetMinutesItemList(int MeetingId)
        {
            DataTable source = MinutesDB.GetMinutesByMeetingId(MeetingId, -1, -1);

            DataTable items = new DataTable();
            items.Columns.Add("AgendaNo", typeof(string));
            items.Columns.Add("SubjectNo", typeof(string));
            items.Columns.Add("ShortText", typeof(string));
            items.Columns.Add("Decision", typeof(string));
            items.Columns.Add("ActualResolution", typeof(string));

            int notSaved = 0;
            DataView ordered = new DataView(source);
            ordered.Sort = "AgendaNo ASC";

            foreach (DataRowView row in ordered)
            {
                bool saved = row["StatusId"] != DBNull.Value && Convert.ToInt32(row["StatusId"]) == 1;
                if (!saved)
                    notSaved++;

                string subjectNo = row["SubjectNo"] == DBNull.Value || Convert.ToInt32(row["SubjectNo"]) == 0
                    ? "-" : Convert.ToInt32(row["SubjectNo"]).ToString();

                string decision, resolution;
                if (!saved)
                {
                    decision = NotYetRecorded;
                    resolution = NotYetRecorded;
                }
                else
                {
                    decision = Convert.ToString(row["DecisionTypeName"]).Trim();
                    if (decision.Length == 0)
                        decision = NotRecorded;
                    resolution = HtmlCleaner.ToPlainText(Convert.ToString(row["ActualResolution"]));
                    if (resolution.Length == 0)
                        resolution = NotRecorded;
                }

                items.Rows.Add(Convert.ToString(row["AgendaNo"]), subjectNo, Convert.ToString(row["ShortText"]), decision, resolution);
            }

            MinutesItemList list = new MinutesItemList();
            list.Items = items;
            list.Total = items.Rows.Count;
            list.NotSaved = notSaved;
            return list;
        }

        public const string NotYetRecorded = "Not yet recorded";
        public const string NotRecorded = "Not recorded";
        #endregion

        #region GetMinutesByMeetingNoFromTo
        public static DataTable GetMinutesByMeetingNoFromTo(int CommitteeId, int MeetingNoFrom, int MeetingNoTo, int StatusId, int DepartmentId)
        {
            return MinutesDB.GetMinutesByMeetingNoFromTo(CommitteeId, MeetingNoFrom, MeetingNoTo, StatusId, DepartmentId);
        }
        #endregion

        #region GetMinutesByMeetingIdAgendaId
        public static DataTable GetMinutesByMeetingIdAgendaId(int MeetingId, int AgendaId)
        {
            return MinutesDB.GetMinutesByMeetingIdAgendaId(MeetingId, AgendaId);
        }
        #endregion

        #region GetMinutesByMinutesId
        public static DataTable GetMinutesByMinutesId(int MinutesId)
        {
            return MinutesDB.GetMinutesByMinutesId(MinutesId);
        }
        #endregion

        #region UpdateMinutes
        public static MeetingChangeResult UpdateMinutes(MinutesBAL myMinutesBAL)
        {
            MinutesDAL myMinutesDAL = new MinutesDAL();

            myMinutesDAL.Code = myMinutesBAL.Code;
            myMinutesDAL.MinutesId = myMinutesBAL.MinutesId;
            myMinutesDAL.DecisionTypeId = myMinutesBAL.DecisionTypeId;
            myMinutesDAL.DueDate = myMinutesBAL.DueDate;   // step UN6a
            myMinutesDAL.SendDueDate = myMinutesBAL.SendDueDate;   // step UN6a1
            myMinutesDAL.Directions = HtmlCleaner.Clean(myMinutesBAL.Directions);   // step A1a
            myMinutesDAL.ActualResolution = HtmlCleaner.Clean(myMinutesBAL.ActualResolution);   // step A1a
            myMinutesDAL.ShortText = myMinutesBAL.ShortText;
            myMinutesDAL.CreatedBy = myMinutesBAL.CreatedBy;
            myMinutesDAL.UpdatedBy = myMinutesBAL.UpdatedBy;

            return MeetingChangeResult.FromTable(MinutesDB.UpdateMinutes(myMinutesDAL));
        }

        // Step UN6a1: true when the database has step 38 (spr_UpdateMinutes takes @DueDate); the page then sends the
        // due dates, otherwise it disables the due date boxes and saves the minutes without them
        public static bool HasDueDateParameter()
        {
            return MinutesDB.HasDueDateParameter();
        }
        #endregion

    }
    #endregion

    #region MinutesItemList
    // Step MF1: the Minutes Items list of a meeting and its counts (MinutesMgr.GetMinutesItemList)
    public class MinutesItemList
    {
        public DataTable Items;
        public int Total;       // rows of the list
        public int NotSaved;    // of them, minutes not saved in Update Minutes (StatusId other than 1)
    }
    #endregion

}
