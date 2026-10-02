using System;
using System.Collections.Generic;
using System.Text;
using System.Security.Cryptography;
using System.Web.UI.WebControls;
using System.Data;
using System.Web;
using Microsoft.Office;
using Microsoft.Office.Interop.Word;
using System.IO;

namespace BMMSBAL
{
    public class DocToString
    {

        #region CreateRandomPassword
        public static string ConvertDocToString(string strFileName, string strFilePath)
        {
            Microsoft.Office.Interop.Word.ApplicationClass objWord = new ApplicationClass();
            string strPathToUpload; //Path to upload files "Uploaded"
            string strPathToConvert; //Path to convert uploaded files and save
            object fltDocFormat = 10; //For filtered HTML Output
            object missing = System.Reflection.Missing.Value;
            object readOnly = false; //Open file in readOnly mode
            object isVisible = false;//The process has to be in invisible mode


            try
            {
                //To check the file extension if it is word document or something else
                string[] strSep = strFileName.Split('.');
                int arrLength = strSep.Length - 1;
                string strExt = strSep[arrLength].ToString().ToUpper();
                //Save the uploaded file to the folder
                strPathToUpload = strFilePath;
                //Map-path to the folder where html to be saved
                strPathToConvert = strFilePath;
                object FileName = strPathToUpload + "\\" + strFileName;
                object FileToSave = strPathToConvert + "\\" + strFileName + ".htm";
                
                strPathToConvert += strFileName + ".htm";
                strPathToUpload += strFileName;

                if (strExt.ToUpper().Equals("DOC") || strExt.ToUpper().Equals("DOCX"))
                {
                    //fUpload.SaveAs(strPathToUpload + "\\" + strFileName);
                    //lblMessage.Text = "File uploaded successfully";
                    //open the file internally in word. In the method all the parameters should be passed by object reference
                    objWord.Documents.Open(ref FileName, ref readOnly, ref missing, ref missing, ref missing, ref missing, ref missing, ref missing, ref missing, ref missing, ref isVisible, ref missing, ref missing, ref missing, ref missing, ref missing);
                    //Do the background activity
                    objWord.Visible = false;
                    Microsoft.Office.Interop.Word.Document oDoc = objWord.ActiveDocument;
                    oDoc.SaveAs(ref FileToSave, ref fltDocFormat, ref missing, ref missing, ref missing, ref missing, ref missing, ref missing, ref missing, ref missing, ref missing, ref missing, ref missing, ref missing, ref missing, ref missing);
                    //lblMessage.Text = filepath + " converted to HTML successfully";
                    oDoc.Close(ref missing, ref missing, ref missing);
                }
                else
                {
                    return "Invalid file selected!";
                }
                //Close/quit word

                objWord.Quit(ref missing, ref missing, ref missing);
            }
            catch (Exception ex)
            {
                return ex.Message;
            }

            string strOutput = string.Empty;

            using (StreamReader reader = new StreamReader(strPathToConvert))
            {
                String line = String.Empty;
                while ((line = reader.ReadLine()) != null)
                {
                    strOutput += line;
                }
            }

            if (File.Exists(strPathToUpload))
                File.Delete(strPathToUpload);

            if (File.Exists(strPathToConvert))
                File.Delete(strPathToConvert);

            return strOutput;
        }
        #endregion





    }
}
