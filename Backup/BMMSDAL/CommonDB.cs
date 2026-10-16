using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using System.Data.SqlClient;

namespace BMMSDAL
{
    public class CommonDB
    {

        #region ExecuteProcedure
        public static int ExecuteProcedure(string ProcedureName, SqlParameter[] ParamArray)
        {
            int result = 0;

            SqlConnection conn = new SqlConnection(ConnectDB.GetConnectionString());
            SqlCommand cmd = new SqlCommand(ProcedureName, conn);
            cmd.CommandType = CommandType.StoredProcedure;

            if (ParamArray != null)
            {
                foreach (SqlParameter p in ParamArray)
                {
                    cmd.Parameters.Add(p);
                }
            }

            try
            {
                conn.Open();

                result = cmd.ExecuteNonQuery();

            }
            catch (Exception ex)
            {
                throw ex;
            }
            finally
            {
                cmd.Parameters.Clear();
                cmd.Dispose();
                conn.Close();
            }

            return result;

        }
        #endregion

        #region GetDataTable
        public static DataTable GetDataTable(string ProcedureName, SqlParameter[] ParamArray)
        {

            DataTable dt = new DataTable();

            SqlConnection conn = new SqlConnection(ConnectDB.GetConnectionString());
            SqlCommand cmd = new SqlCommand(ProcedureName, conn);
            cmd.CommandType = CommandType.StoredProcedure;

            if (ParamArray != null)
            {
                foreach (SqlParameter p in ParamArray)
                {
                    cmd.Parameters.Add(p);
                }
            }

            try
            {
                conn.Open();

                SqlDataAdapter da = new SqlDataAdapter(cmd);

                da.Fill(dt);
            }
            catch (Exception ex)
            {
                throw ex;
            }
            finally
            {
                cmd.Parameters.Clear();
                cmd.Dispose();
                conn.Close();
            }

            return dt;

        }
        #endregion

        #region GetDataTableFromQuery
        public static DataTable GetDataTableFromQuery(string SQL_Query_Text)
        {

            DataTable dt = new DataTable();

            SqlConnection conn = new SqlConnection(ConnectDB.GetConnectionString());
            SqlCommand cmd = new SqlCommand(SQL_Query_Text, conn);
            cmd.CommandType = CommandType.Text;

            try
            {
                conn.Open();

                SqlDataAdapter da = new SqlDataAdapter(cmd);

                da.Fill(dt);
            }
            catch (Exception ex)
            {
                throw ex;
            }
            finally
            {
                cmd.Parameters.Clear();
                cmd.Dispose();
                conn.Close();
            }

            return dt;

        }
        #endregion
    }
}
