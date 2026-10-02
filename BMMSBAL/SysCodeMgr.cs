using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region SysCode
    public class SysCode
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

    #region SysCodeList
    public class SysCodeList : List<SysCode>
    {
        #region public SysCodeList()
        public SysCodeList()
        {

        }
        #endregion
    }
    #endregion

    #region SysCodeMgr
    public class SysCodeMgr
    {
        #region GetSysCodeSetting
        public static DataTable GetSysCodeSetting(string MainCode)
        {
            return SysCodeDB.GetSysCodeSetting(MainCode);
        }
        #endregion
        
    }
    #endregion

}
