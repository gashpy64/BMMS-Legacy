using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region DepartmentBAL
    public class DepartmentBAL
    {
        #region Properties

        private string _Code;
        private int _DepartmentId;
        private string _DepartmentCode;
        private string _DepartmentName;
        private int _OrderNo;
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
        public int DepartmentId
        {
            get { return _DepartmentId; }
            set { _DepartmentId = value; }
        }
        public string DepartmentCode
        {
            get { return _DepartmentCode; }
            set { _DepartmentCode = value; }
        }
        public string DepartmentName
        {
            get { return _DepartmentName; }
            set { _DepartmentName = value; }
        }
        public int OrderNo
        {
            get { return _OrderNo; }
            set { _OrderNo = value; }
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

    #region DepartmentBALList
    public class DepartmentBALList : List<DepartmentBAL>
    {
        #region public DepartmentBALList()
        public DepartmentBALList()
        {

        }
        #endregion
    }
    #endregion

    #region DepartmentMgr
    public class DepartmentMgr
    {

        #region GetDepartmentList
        public static DataTable GetDepartmentList(int StatusId)
        {
            return DepartmentDB.GetDepartmentList(StatusId);
        }
        #endregion

        #region GetDashboardDepartments
        // Step UN6b: the departments of a Manager or a User for the Dashboard (spr_GetDashboardDepartments)
        public static DataTable GetDashboardDepartments(int ActingUserId, out int Reason)
        {
            return DepartmentDB.GetDashboardDepartments(ActingUserId, out Reason);
        }
        #endregion

        #region GetManagerDepartments
        // Step UD1c (BMMS-Fix-ManagerScope-Step54.sql): the acting Manager's departments (spr_GetManagerDepartments: home
        // first; IsHome, IsActive) for Agenda Entry and the reports. Reason 0 when allowed, otherwise 8 or 4, then no rows.
        public static DataTable GetManagerDepartments(int ActingUserId, out int Reason)
        {
            return DepartmentDB.GetManagerDepartments(ActingUserId, out Reason);
        }

        /// <summary>Step UD1c: the text of a Manager's department in a drop-down: the name, " (home)" for the home
        /// department, " (inactive)" for an inactive one. Plain text (a ListItem encodes it).</summary>
        public static string ManagerDepartmentText(DataRow Row)
        {
            return Convert.ToString(Row["DepartmentName"])
                 + (Convert.ToBoolean(Row["IsHome"]) ? " (home)" : string.Empty)
                 + (Convert.ToBoolean(Row["IsActive"]) ? string.Empty : " (inactive)");
        }

        /// <summary>Step UD1c: the first item of a Manager's department filter (value 0 or -1 as the page needs it).</summary>
        public const string AllMyDepartmentsText = "All my departments";
        #endregion

        #region GetNextDeptCode
        public static string GetNextDeptCode()
        {
            return DepartmentDB.GetNextDeptCode();
        }
        #endregion

        #region GetDepartmentByDeptId
        public static DepartmentBAL GetDepartmentByDeptId(int DeptId)
        {
            DepartmentDAL deptDAL = new DepartmentDAL();
            deptDAL = DepartmentDB.GetDepartmentByDeptId(DeptId);

            DepartmentBAL deptBAL = new DepartmentBAL();
            deptBAL.DepartmentId = deptDAL.DepartmentId;
            deptBAL.DepartmentCode = deptDAL.DepartmentCode;
            deptBAL.DepartmentName = deptDAL.DepartmentName;
            deptBAL.OrderNo = deptDAL.OrderNo;
            deptBAL.StatusId = deptDAL.StatusId;

            return deptBAL;
        }
        #endregion

        #region AddEditDepartment
        /// <summary>
        /// Step GM1a (BMMS-Fix-GovernanceLog-Step56.sql): the save with the acting user, which the procedure checks
        /// before anything is changed (Reason 8 missing or inactive, 4 not an Admin). 1 when saved; Message the text for
        /// the page when not (null when saved).
        /// </summary>
        public int AddEditDepartment(DepartmentBAL deptBAL, int ActingUserId, out string Message)
        {
            DepartmentDAL deptDAL = new DepartmentDAL();
            deptDAL.Code = deptBAL.Code;
            deptDAL.DepartmentId = deptBAL.DepartmentId;
            deptDAL.DepartmentCode = deptBAL.DepartmentCode;
            deptDAL.DepartmentName = deptBAL.DepartmentName;
            deptDAL.OrderNo = deptBAL.OrderNo;
            deptDAL.StatusId = deptBAL.StatusId;
            deptDAL.CreatedOn = deptBAL.CreatedOn;
            deptDAL.CreatedBy = deptBAL.CreatedBy;
            deptDAL.UpdatedOn = deptBAL.UpdatedOn;
            deptDAL.UpdatedBy = deptBAL.UpdatedBy;

            int reason;
            int result = DepartmentDB.AddEditDepartment(deptDAL, ActingUserId, out reason);

            if (result == 1)
                Message = null;
            else if (reason == 8)
                Message = "Not saved: your account is not active. Sign in again. Nothing was changed.";
            else if (reason == 4)
                Message = "Not saved: only an Admin can change departments. Nothing was changed.";
            else
                Message = "Record Not Saved";
            return result;
        }
        #endregion

        #region DeleteDepartmentByDeptId
        public static int DeleteDepartmentByDeptId(int DeptId)
        {
            return DepartmentDB.DeleteDepartmentByDeptId(DeptId);
        }
        #endregion

        #region DeleteDepartment
        /// <summary>
        /// Step UD1a: deletes the department and returns the message for the page (null when it was deleted).
        /// Reason 25 (BMMS-Fix-UserHistory-Step39.sql): still mapped to users (ReasonDetail "Mapped:names") or used in
        /// the department history ("History"); any other refusal keeps the general "in use" message. Without
        /// step 39 the procedure returns Result only, as before.
        /// </summary>
        public static string DeleteDepartment(int DeptId)
        {
            DataTable dt = DepartmentDB.DeleteDepartment(DeptId);

            if (dt.Rows.Count > 0 && Convert.ToInt32(dt.Rows[0]["Result"]) == 1)
                return null;

            if (dt.Rows.Count > 0 && dt.Columns.Contains("Reason") && Convert.ToInt32(dt.Rows[0]["Reason"]) == 25)
            {
                string detail = Convert.ToString(dt.Rows[0]["ReasonDetail"]);
                const string mapped = "Mapped:";

                if (detail.StartsWith(mapped, StringComparison.Ordinal))
                    return "This department cannot be deleted: it is mapped to "
                         + System.Web.HttpUtility.HtmlEncode(detail.Substring(mapped.Length))
                         + ". Remove it from them in User Master first, or make it inactive.";

                return "This department cannot be deleted: it is used in the department history of users. Make it inactive instead.";
            }

            return Common.GetAppSetting("delete_reference");
        }
        #endregion
        
    }
    #endregion

}
