using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;


namespace BMMSDAL
{
    #region SysCodeDAL
    public class SysCodeDAL
    {
        #region Properties

        private string _MainCode;
        private string _SubCode;
        private string _DisplayName;

        public string MainCode
        {
            get { return _MainCode; }
            set { _MainCode = value; }
        }
        public string SubCode
        {
            get { return _SubCode; }
            set { _SubCode = value; }
        }
        public string DisplayName
        {
            get { return _DisplayName; }
            set { _DisplayName = value; }
        }

        #endregion
    }
    #endregion

    #region SysCodeDALList
    public class SysCodeDALList : List<SysCodeDAL>
    {
        #region public SysCodeDALList()
        public SysCodeDALList()
        {

        }
        #endregion
    }
    #endregion

    

    #region SysCodeDB
    public class SysCodeDB
    {

        #region GetSysCodeSetting
        public static DataTable GetSysCodeSetting(string MainCode)
        {
            DataTable dt = new DataTable();

            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MainCode", MainCode);

            dt = CommonDB.GetDataTable("spr_GetSysCodeSetting", parameter);
            return dt;
        }
        #endregion
    }
    #endregion
    
}
