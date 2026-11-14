using System;
using System.Data.SqlClient;
using System.IO;

namespace BMMSBAL
{
    public class Sql_Backup_Mgr
    {
        #region BackupDatabase
        // Plain T-SQL backup; no SMO needed. SQL Server itself writes the .bak file,
        // so destinationPath must be writable by the SQL Server service account.
        public static void BackupDatabase(string destinationPath)
        {
            string folder = Path.GetDirectoryName(destinationPath);
            if (!Directory.Exists(folder)) Directory.CreateDirectory(folder);

            using (SqlConnection con = new SqlConnection(BMMSDAL.ConnectDB.GetConnectionString()))
            {
                con.Open();
                string db = con.Database.Replace("]", "]]");
                string sql = "BACKUP DATABASE [" + db + "] TO DISK = @path " +
                             "WITH INIT, CHECKSUM, NAME = N'BMMS Archive'";
                using (SqlCommand cmd = new SqlCommand(sql, con))
                {
                    cmd.CommandTimeout = 600;
                    cmd.Parameters.AddWithValue("@path", destinationPath);
                    cmd.ExecuteNonQuery();
                }
            }
        }
        #endregion
    }
}