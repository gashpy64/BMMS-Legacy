using System;
using System.Data;
using System.Data.SqlClient;

namespace BMMSDAL
{
    #region GovernanceDB
    // Step GM1a (BMMS-Fix-GovernanceLog-Step56.sql): the reads of the Governance Matrix page. Every procedure takes the
    // acting user and decides itself (Admin and Controller only: Reason 8 acting user missing or inactive, 4 another
    // role; 32 a date before the history start, 33 a date missing or after today, 34 a change log range that is not
    // valid); then no rows. Reason 0 when allowed. Detail: the history start (yyyy-mm-dd) for Reason 32.
    public class GovernanceDB
    {
        #region Matrix
        // The people of every rule as on @AsOn (Kind P) and the people of every role (Kind H)
        public static DataTable GetMatrix(int ActingUserId, DateTime AsOn, out int Reason, out string Detail)
        {
            return ReadDated("spr_GetGovernanceMatrix", ActingUserId, AsOn, out Reason, out Detail);
        }

        // One row: Today, HistoryStart, LogFrom, IsLive, DeptNoManagerAction, AgendaControllerBypass as on @AsOn
        public static DataTable GetSettings(int ActingUserId, DateTime AsOn, out int Reason, out string Detail)
        {
            return ReadDated("spr_GetGovernanceSettings", ActingUserId, AsOn, out Reason, out Detail);
        }

        // The departments: DepartmentId, DepartmentName, IsActive as on @AsOn, OrderNo
        public static DataTable GetDepartments(int ActingUserId, DateTime AsOn, out int Reason, out string Detail)
        {
            return ReadDated("spr_GetGovernanceDepartments", ActingUserId, AsOn, out Reason, out Detail);
        }

        private static DataTable ReadDated(string Procedure, int ActingUserId, DateTime AsOn, out int Reason, out string Detail)
        {
            SqlParameter result = new SqlParameter("@Result", SqlDbType.Int);
            result.Direction = ParameterDirection.Output;
            SqlParameter reason = new SqlParameter("@Reason", SqlDbType.Int);
            reason.Direction = ParameterDirection.Output;
            SqlParameter detail = new SqlParameter("@Detail", SqlDbType.VarChar, 10);
            detail.Direction = ParameterDirection.Output;

            SqlParameter[] parameter = new SqlParameter[5];
            parameter[0] = new SqlParameter("@ActingUserId", ActingUserId);
            parameter[1] = new SqlParameter("@AsOn", SqlDbType.Date);
            parameter[1].Value = AsOn.Date;
            parameter[2] = result;
            parameter[3] = reason;
            parameter[4] = detail;

            DataTable dt = CommonDB.GetDataTable(Procedure, parameter);
            Reason = MinutesDB.RefusalReason(result, reason);
            Detail = detail.Value == null || detail.Value == DBNull.Value ? string.Empty : Convert.ToString(detail.Value);
            return dt;
        }
        #endregion

        #region ChangeLog
        // The change log rows of the days From to To, newest first; UserId, DepartmentId 0 and ChangeType "" = all
        public static DataTable GetChangeLog(int ActingUserId, DateTime From, DateTime To, int UserId, int DepartmentId, string ChangeType, out int Reason)
        {
            SqlParameter result = new SqlParameter("@Result", SqlDbType.Int);
            result.Direction = ParameterDirection.Output;
            SqlParameter reason = new SqlParameter("@Reason", SqlDbType.Int);
            reason.Direction = ParameterDirection.Output;

            SqlParameter[] parameter = new SqlParameter[8];
            parameter[0] = new SqlParameter("@ActingUserId", ActingUserId);
            parameter[1] = new SqlParameter("@From", SqlDbType.Date);
            parameter[1].Value = From.Date;
            parameter[2] = new SqlParameter("@To", SqlDbType.Date);
            parameter[2].Value = To.Date;
            parameter[3] = new SqlParameter("@UserId", UserId <= 0 ? (object)DBNull.Value : UserId);
            parameter[4] = new SqlParameter("@DepartmentId", DepartmentId <= 0 ? (object)DBNull.Value : DepartmentId);
            parameter[5] = new SqlParameter("@ChangeType", SqlDbType.Char, 2);
            parameter[5].Value = string.IsNullOrEmpty(ChangeType) ? (object)DBNull.Value : ChangeType;
            parameter[6] = result;
            parameter[7] = reason;

            DataTable dt = CommonDB.GetDataTable("spr_GetGovernanceChangeLog", parameter);
            Reason = MinutesDB.RefusalReason(result, reason);
            return dt;
        }

        // The users of the change log's user filter: UserId, UserName, LoginName, IsActive, Deleted
        public static DataTable GetLogUsers(int ActingUserId, out int Reason)
        {
            SqlParameter result = new SqlParameter("@Result", SqlDbType.Int);
            result.Direction = ParameterDirection.Output;
            SqlParameter reason = new SqlParameter("@Reason", SqlDbType.Int);
            reason.Direction = ParameterDirection.Output;

            SqlParameter[] parameter = new SqlParameter[3];
            parameter[0] = new SqlParameter("@ActingUserId", ActingUserId);
            parameter[1] = result;
            parameter[2] = reason;

            DataTable dt = CommonDB.GetDataTable("spr_GetGovernanceLogUsers", parameter);
            Reason = MinutesDB.RefusalReason(result, reason);
            return dt;
        }
        #endregion
    }
    #endregion
}
