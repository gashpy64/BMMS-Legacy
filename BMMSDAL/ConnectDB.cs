using System;
using System.Collections.Generic;
using System.Text;
using System.Configuration;
using System.Data.SqlClient;

namespace BMMSDAL
{
    public class ConnectDB
    {
        #region GetConnectionString
        public static String GetConnectionString()
        {
            return ConfigurationManager.ConnectionStrings["ConnectionString"].ConnectionString;
        }
        #endregion

        #region GetConnectedDatabaseName
        // Step F1: the database the server opened for the application's connection (SqlConnection.Database after
        // Open), not the text of the connection string; the server name is not read. Throws when the connection
        // cannot be opened (the caller, Common.FooterDatabaseName, logs it).
        public static String GetConnectedDatabaseName()
        {
            using (SqlConnection conn = new SqlConnection(GetConnectionString()))
            {
                conn.Open();
                return conn.Database;
            }
        }
        #endregion

    }
}
