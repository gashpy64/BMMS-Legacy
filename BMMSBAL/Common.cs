using System;
using System.Collections.Generic;
using System.Text;
using System.Security.Cryptography;
using System.Web.UI.WebControls;
using System.Data;
using System.Web;
using System.Xml;
using BMMSDAL;
using System.Data.SqlClient;

namespace BMMSBAL
{
    public class Common
    {
        private static string lscryptoKey = "";
        private static byte[] lbtVector = { 240, 3, 45, 29, 0, 76, 173, 59 };

        #region DecryptVal
        public static string DecryptVal(string sEncryptVal)
        {
            byte[] buffer;
            TripleDESCryptoServiceProvider loCryptoClass = new TripleDESCryptoServiceProvider();
            MD5CryptoServiceProvider loCryptoProvider = new MD5CryptoServiceProvider();
            try
            {
                buffer = Convert.FromBase64String(sEncryptVal);
                loCryptoClass.Key = loCryptoProvider.ComputeHash(ASCIIEncoding.ASCII.GetBytes(lscryptoKey));
                loCryptoClass.IV = lbtVector;
                return Encoding.ASCII.GetString(loCryptoClass.CreateDecryptor().TransformFinalBlock(buffer, 0, buffer.Length));
            }
            catch (Exception ex)
            {
                throw ex;
            }
            finally
            {
                loCryptoClass.Clear();
                loCryptoProvider.Clear();
                loCryptoClass = null;
                loCryptoProvider = null;
            }
        }
        #endregion

        #region EncryptVal
        public static string EncryptVal(string sInputVal)
        {
            TripleDESCryptoServiceProvider loCryptoClass = new TripleDESCryptoServiceProvider();
            MD5CryptoServiceProvider loCryptoProvider = new MD5CryptoServiceProvider();
            byte[] lbtBuffer;
            try
            {
                lbtBuffer = System.Text.Encoding.ASCII.GetBytes(sInputVal);
                loCryptoClass.Key = loCryptoProvider.ComputeHash(ASCIIEncoding.ASCII.GetBytes(lscryptoKey));
                loCryptoClass.IV = lbtVector;
                sInputVal = Convert.ToBase64String(loCryptoClass.CreateEncryptor().TransformFinalBlock(lbtBuffer, 0, lbtBuffer.Length));
                return sInputVal;
            }
            catch (CryptographicException ex)
            {
                throw ex;
            }
            catch (FormatException ex)
            { throw ex; }
            catch (Exception ex)
            { throw ex; }
            finally
            {
                loCryptoClass.Clear();
                loCryptoProvider.Clear();
                loCryptoClass = null;
                loCryptoProvider = null;
            }
        }
        #endregion


        #region GetAppSetting
        public static string GetAppSetting(string KeyName)
        {
            string strOutput = string.Empty;
            string XMLFileName = HttpContext.Current.Server.MapPath("~/XML") + @"\AppSettings.xml";

            XmlDocument xmlDocument = new XmlDocument();

            xmlDocument.Load(XMLFileName);

            XmlNode xmlNode = xmlDocument.SelectSingleNode("appSettings");

            foreach (XmlNode childNode in xmlNode)
            {
                if (childNode.Attributes["key"].Value == KeyName)
                {
                    strOutput = childNode.Attributes["value"].Value;

                    break;
                }
            }

            return strOutput;

            //return System.Configuration.ConfigurationManager.AppSettings.Get(KeyName);
        }
        #endregion

        #region GetReportSettings
        public static string GetReportSettings(string KeyName)
        {
            string strOutput = string.Empty;
            string XMLFileName = HttpContext.Current.Server.MapPath("~/XML") + @"\ReportSettings.xml";

            XmlDocument xmlDocument = new XmlDocument();

            xmlDocument.Load(XMLFileName);

            XmlNode xmlNode = xmlDocument.SelectSingleNode("repoSettings");

            foreach (XmlNode childNode in xmlNode)
            {
                if (childNode.Attributes["key"].Value == KeyName)
                {
                    strOutput = childNode.Attributes["value"].Value;

                    break;
                }
            }

            return strOutput;
        }
        #endregion

        #region InitSetup
        public static void InitSetup(string className)
        {
            if (HttpContext.Current.Session["UserName"] == null)
            {
                HttpContext.Current.Response.Redirect("~/", true);
            }
            else
            {
                string XMLFileName = HttpContext.Current.Server.MapPath("~/XML") + @"\PageSettings.xml";

                XmlDocument xmlDocument = new XmlDocument();

                xmlDocument.Load(XMLFileName);

                XmlNode xmlNode = xmlDocument.SelectSingleNode("pageSettings");

                foreach (XmlNode childNode in xmlNode)
                {
                    if (childNode.Attributes["Name"].Value == className)
                    {
                        XmlNode childNoteInner = null;

                        childNoteInner = childNode.SelectSingleNode("pageTitle");
                        HttpContext.Current.Session["PageTitle"] = Common.GetAppSetting("PageTitle") + childNoteInner.InnerText;

                        childNoteInner = childNode.SelectSingleNode("pageURL");
                        HttpContext.Current.Session["PageURL"] = childNoteInner.InnerText;

                        break;
                    }
                }


                //HttpContext.Current.Session["PageURL"] =

            }
        }
        #endregion





        #region GetFinStartDate
        public static string GetFinStartDate()
        {
            if (int.Parse(DateTime.Now.ToString("MM")) <= 3)
                return "01-Apr-" + DateTime.Now.AddYears(-1).ToString("yyyy");
            else
                return "01-Apr-" + DateTime.Now.ToString("yyyy");
        }
        #endregion




        #region LoadDropdownlist
        public static void LoadDropdownlist(DropDownList ddl, DataTable dt, string _DataTextField, string _DataValueField, bool SetDefaultValue)
        {
            ddl.Items.Clear();
            ddl.DataSource = dt;
            ddl.DataTextField = _DataTextField;
            ddl.DataValueField = _DataValueField;
            ddl.DataBind();

            if (SetDefaultValue == true)
            {
                ListItem lst = new ListItem("- Select -", "0");
                ddl.Items.Insert(0, lst);
            }
        }
        #endregion

        #region LoadDDLwithAll
        public static void LoadDDLwithAll(DropDownList ddl, DataTable dt, string _DataTextField, string _DataValueField, bool SetDefaultValue)
        {
            ddl.Items.Clear();
            ddl.DataSource = dt;
            ddl.DataTextField = _DataTextField;
            ddl.DataValueField = _DataValueField;
            ddl.DataBind();

            if (SetDefaultValue == true)
            {
                ListItem lst = new ListItem("- All -", "All");
                ddl.Items.Insert(0, lst);
            }
        }
        #endregion

        #region LoadDDLwithAllNew
        public static void LoadDDLwithAllNew(DropDownList ddl, DataTable dt, string _DataTextField, string _DataValueField, bool SetDefaultValue)
        {
            ddl.Items.Clear();
            ddl.DataSource = dt;
            ddl.DataTextField = _DataTextField;
            ddl.DataValueField = _DataValueField;
            ddl.DataBind();

            if (SetDefaultValue == true)
            {
                ListItem lst = new ListItem("- All -", "-1");
                ddl.Items.Insert(0, lst);
            }
        }
        #endregion

        #region LoadMemberDetails
        public static string LoadMemberDetails(int MemberId)
        {
            DataTable dtMember = new DataTable();
            dtMember = MemberMgr.GetMemberDTbyMemberId(MemberId);

            string MemberDetails = string.Empty;

            if (dtMember.Rows.Count > 0)
            {
                MemberDetails += "<u><b>Member Details :</b></u>";
                MemberDetails += "<br /><b>Member Code  : </b>" + dtMember.Rows[0]["MemberCode"].ToString();
                MemberDetails += "<br /><b>Member Name  : </b>" + dtMember.Rows[0]["MemberName"].ToString();
                MemberDetails += "<br /><b>Designation  : </b>" + dtMember.Rows[0]["DesignationName"].ToString();
                MemberDetails += "<br /><b>Date of Join : </b>" + dtMember.Rows[0]["DOJ"].ToString();
                MemberDetails += "<br /><b>EmailId : </b>" + dtMember.Rows[0]["EmailId"].ToString();
            }
            return MemberDetails;
        }
        #endregion

        #region SaveSendMail
        public static int SaveSendMail(string Mail_To, string Mail_Subject, string Mail_Body_Text, string Mail_Attachment_Path, int Mail_Send_By)
        {
            SqlParameter[] parameter = new SqlParameter[5];
            parameter[0] = new SqlParameter("@Mail_To", Mail_To);
            parameter[1] = new SqlParameter("@Mail_Subject", Mail_Subject);
            parameter[2] = new SqlParameter("@Mail_Body_Text", Mail_Body_Text);
            if (Mail_Attachment_Path != null)
                parameter[3] = new SqlParameter("@Mail_Attachment_Path", Mail_Attachment_Path);
            else
                parameter[3] = new SqlParameter("@Mail_Attachment_Path", "-");
            parameter[4] = new SqlParameter("@Mail_Send_By", Mail_Send_By);

            return CommonDB.ExecuteProcedure("spr_SaveSendMail", parameter);

        }
        #endregion

        #region GetCommitteeMemberMailId
        public static string GetCommitteeMemberMailId(int CommitteeId, int MeetingId)
        {
            DataTable dtCommitteeMember = new DataTable();
            dtCommitteeMember = CommitteeMemberMgr.GetCommitteeMemberByCommitteeId(CommitteeId, MeetingId);

            string MailId = string.Empty;

            for (int i = 0; i < dtCommitteeMember.Rows.Count; i++)
            {
                if (dtCommitteeMember.Rows[i]["CessationDate"].ToString().Trim() == string.Empty)
                {
                    if (i == dtCommitteeMember.Rows.Count - 1)
                        MailId += dtCommitteeMember.Rows[i]["EmailId"].ToString();
                    else
                        MailId += dtCommitteeMember.Rows[i]["EmailId"].ToString() + ", ";
                }
                else
                {
                    try
                    {
                        DateTime CessationDate = Convert.ToDateTime(dtCommitteeMember.Rows[i]["CessationDate"].ToString());
                        if (CessationDate >= System.DateTime.Now)
                        {
                            if (i == dtCommitteeMember.Rows.Count - 1)
                                MailId += dtCommitteeMember.Rows[i]["EmailId"].ToString();
                            else
                                MailId += dtCommitteeMember.Rows[i]["EmailId"].ToString() + ", ";
                        }
                    }
                    catch (Exception ex)
                    {

                    }
                }

            }

            return MailId;

        }
        #endregion

        #region LoadUserDetails
        public static string LoadUserDetails(DataTable dtUser)
        {
            string UserDetails = string.Empty;

            if (dtUser.Rows.Count > 0)
            {
                UserDetails += "<u><b>User Details :</b></u>";
                UserDetails += "<br /><b>User Name     : </b>" + dtUser.Rows[0]["UserName"].ToString();
                UserDetails += "<br /><b>Department    : </b>" + dtUser.Rows[0]["DepartmentName"].ToString();
                UserDetails += "<br /><b>Designation   : </b>" + dtUser.Rows[0]["DesignationName"].ToString();
                UserDetails += "<br /><b>Date of Birth : </b>" + dtUser.Rows[0]["DOB"].ToString();
                UserDetails += "<br /><b>Email Id      : </b>" + dtUser.Rows[0]["EmailId"].ToString();
            }
            return UserDetails;
        }
        #endregion

        #region CreateRandomPassword
        public static string CreateRandomPassword(int PasswordLength)
        {
            string _allowedChars = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ0123456789";
            Random randNum = new Random();
            char[] chars = new char[PasswordLength];
            int allowedCharCount = _allowedChars.Length;

            for (int i = 0; i < PasswordLength; i++)
            {
                chars[i] = _allowedChars[(int)((_allowedChars.Length) * randNum.NextDouble())];
            }

            return new string(chars);
        }
        #endregion

        #region MondifyAppSettings
        public static string MondifyAppSettings(string KeyName, string NewValue)
        {
            try
            {
                string xmlFileWithPath = HttpContext.Current.Server.MapPath("~/XML") + @"\AppSettings.xml";

                XmlDocument xmlDoc = new XmlDocument();

                xmlDoc.Load(xmlFileWithPath);

                XmlNode appSettingsNode = xmlDoc.SelectSingleNode("appSettings");

                foreach (XmlNode childNode in appSettingsNode)
                {
                    if (childNode.Attributes["key"] != null)
                    {
                        if (childNode.Attributes["key"].Value == KeyName)
                            childNode.Attributes["value"].Value = NewValue;
                    }
                }

                xmlDoc.Save(xmlFileWithPath);

                return ("Success");
            }
            catch (Exception ex)
            {
                return "Error : " + ex.ToString();
            }

        }

        #endregion

        #region HashPassword / VerifyPassword
        // PBKDF2 (RFC 2898), 100,000 iterations, 16-byte random salt per password.
        // Stored format: "100000.<base64 salt>.<base64 hash>" — self-describing,
        // so the iteration count can be raised later without breaking old hashes.
        private const int HashIterations = 100000;
        private const int HashSaltSize = 16;
        private const int HashKeySize = 32;

        public static string HashPassword(string plainPassword)
        {
            using (var rng = new RNGCryptoServiceProvider())
            {
                byte[] salt = new byte[HashSaltSize];
                rng.GetBytes(salt);
                using (var pbkdf2 = new Rfc2898DeriveBytes(plainPassword, salt, HashIterations))
                {
                    return HashIterations + "." + Convert.ToBase64String(salt) + "." +
                           Convert.ToBase64String(pbkdf2.GetBytes(HashKeySize));
                }
            }
        }
        // Old format = a single base64 blob. New format = "iterations.salt.hash".
        public static bool IsLegacyFormat(string stored)
        {
            if (string.IsNullOrEmpty(stored)) return false;
            string[] parts = stored.Split('.');
            int n;
            return !(parts.Length == 3 && int.TryParse(parts[0], out n));
        }
        public static bool VerifyPassword(string plainPassword, string stored)
        {
            if (string.IsNullOrEmpty(stored)) return false;

            if (IsLegacyFormat(stored)) return false;
           
            string[] parts = stored.Split('.');
            int iterations;
            byte[] salt, expected;
            try
            {
                iterations = int.Parse(parts[0]);
                salt = Convert.FromBase64String(parts[1]);
                expected = Convert.FromBase64String(parts[2]);
            }
            catch (FormatException) { return false; }

            using (var pbkdf2 = new Rfc2898DeriveBytes(plainPassword, salt, iterations))
            {
                byte[] actual = pbkdf2.GetBytes(expected.Length);
                if (actual.Length != expected.Length) return false;
                int diff = 0;                       // constant-time compare
                for (int i = 0; i < actual.Length; i++) diff |= actual[i] ^ expected[i];
                return diff == 0;
            }
        }

        // Constant-time comparison — a plain == or SequenceEqual leaks timing
        // information about how many leading bytes matched, which is the kind
        // of side channel password-verification code should avoid.
        private static bool FixedTimeEquals(byte[] a, byte[] b)
        {
            if (a.Length != b.Length) return false;
            int diff = 0;
            for (int i = 0; i < a.Length; i++)
                diff |= a[i] ^ b[i];
            return diff == 0;
        }


        #endregion
        #region ProtectSecret / UnprotectSecret
        // For secrets that must stay recoverable (e.g. the SMTP password).
        // Windows DPAPI, machine scope: no key in code or config. The stored value
        // can only be decrypted on this machine, so after restoring the database on
        // another server the SMTP password must be re-entered once.
        private static readonly byte[] SecretEntropy = Encoding.UTF8.GetBytes("BMMS.Secret.v1");
        private const string SecretPrefix = "dpapi:";

        public static string ProtectSecret(string plainText)
        {
            byte[] data = Encoding.UTF8.GetBytes(plainText);
            byte[] enc = ProtectedData.Protect(data, SecretEntropy, DataProtectionScope.LocalMachine);
            return SecretPrefix + Convert.ToBase64String(enc);
        }

        public static string UnprotectSecret(string stored)
        {
            if (string.IsNullOrEmpty(stored)) return stored;

            // TRANSITIONAL: a value saved before this change has no prefix. Remove
            // this line once the SMTP password has been re-saved.
            if (!stored.StartsWith(SecretPrefix)) return DecryptVal(stored);

            byte[] enc = Convert.FromBase64String(stored.Substring(SecretPrefix.Length));
            byte[] data = ProtectedData.Unprotect(enc, SecretEntropy, DataProtectionScope.LocalMachine);
            return Encoding.UTF8.GetString(data);
        }
        #endregion
    }
}
