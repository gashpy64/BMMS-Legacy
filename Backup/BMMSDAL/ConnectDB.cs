using System;
using System.Collections.Generic;
using System.Text;
using System.Configuration;

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

    }
}
