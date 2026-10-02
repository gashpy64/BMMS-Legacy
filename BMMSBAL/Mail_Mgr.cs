using System;
using System.Collections.Generic;
using System.Text;
using System.IO;
using System.Web;
using System.Data;
using System.Collections;
using System.Web.Mail;

namespace BMMSBAL
{
    public class Mail_Mgr
    {      

        #region SendWebEmail
        public static string SendWebEmail(string ToMailId, string Subject, string BodyText, string AttachFileName, string Bcc)
        {

            string pSMTPServer = string.Empty;
            string pSMTPServerPort = string.Empty;
            string pUserName = string.Empty;
            string pPassword = string.Empty;

            try
            {
                DataTable dtSMTPMaster = Utilities.GetSMTPMaster();

                pSMTPServer = dtSMTPMaster.Rows[0]["SMTPServer"].ToString();
                pSMTPServerPort = dtSMTPMaster.Rows[0]["SMTPServerPort"].ToString();
                pUserName = dtSMTPMaster.Rows[0]["UserName"].ToString();
                pPassword = Common.DecryptVal(dtSMTPMaster.Rows[0]["Password"].ToString());

                string pFromMailId = dtSMTPMaster.Rows[0]["FromMailId"].ToString();

                string pBcc = dtSMTPMaster.Rows[0]["Bcc"].ToString();

                string pTo = string.Empty;

                string pSubject = string.Empty;

                pSubject = Subject;

                pTo = ToMailId;

                if (Bcc != null)
                    pBcc += ", " + Bcc;
                else
                    pBcc = Bcc;

                string pBody = BodyText;


                MailMessage eMail = new MailMessage();

                eMail.From = pFromMailId;
                eMail.To = pTo;

                if (pBcc != null)
                    if (pBcc.Trim() != string.Empty)
                        eMail.Bcc = pBcc;

                eMail.Subject = pSubject;

                eMail.BodyFormat = MailFormat.Html;
                pBody += "<br /> <br /> <b>Note :</b> This alert is generated from";
                pBody += "<b> Board Minutes and Management Software </b>";
                pBody += "for your information. Please do not reply.";
                eMail.Body = pBody;


                if (AttachFileName != null)
                    eMail.Attachments.Add(new MailAttachment(AttachFileName));

                eMail.Fields["http://schemas.microsoft.com/cdo/configuration/smtsperver"] = pSMTPServer;
                eMail.Fields[
                    "http://schemas.microsoft.com/cdo/configuration/smtpserverport"] = 25;
                eMail.Fields[
                    "http://schemas.microsoft.com/cdo/configuration/sendusing"] = 2;

                eMail.Fields[
                    "http://schemas.microsoft.com/cdo/configuration/smtpauthenticate"] = 1;
                eMail.Fields[
                    "http://schemas.microsoft.com/cdo/configuration/sendusername"] = pUserName;
                eMail.Fields[
                    "http://schemas.microsoft.com/cdo/configuration/sendpassword"] = pPassword;

                //first.Fields["http://schemas.microsoft.com/cdo/configuration/smtpserverpickupdirectory"] = "C:/inetpub/mailroot/pickup";

                SmtpMail.SmtpServer = pSMTPServer;
                SmtpMail.Send(eMail);

                Common.SaveSendMail(ToMailId, Subject, BodyText, AttachFileName, int.Parse(HttpContext.Current.Session["UserId"].ToString()));

                return "Success";
            }
            catch (Exception ex)
            {
                string msg = string.Empty;
                //msg += "| SMTPServer = " + pSMTPServer + " | ";
                //msg += "| SMTPServerPort = " + pSMTPServerPort + " | ";
                //msg += "| UserName = " + pUserName + " | ";
                //msg += "| Password = " + pPassword + " | ";

                Utilities.WriteErrorLog("Mail_Mgr", "SendWebEmail", ex.ToString() + msg.ToString());
                return "Error: " + ex.Message.ToString();
            }
        }
        #endregion


        #region SendEmail
        public static string SendEmail(string ToMailId, string Subject, string BodyText)
        {
            try
            {
                string pGmailEmail = "xxx@gmail.com";
                string pGmailPassword = "xxx";

                string pTo = ToMailId;
                string pBcc = string.Empty;
                string pSubject = Subject;

                pBcc = "xxx@gmail.com";


                System.Web.Mail.MailFormat pFormat = MailFormat.Html;
                string pAttachmentPath = "";
                string pBody = BodyText;

                System.Web.Mail.MailMessage myMail = new System.Web.Mail.MailMessage();
                myMail.Fields.Add
                    ("http://schemas.microsoft.com/cdo/configuration/smtpserver",
                                  "smtp.gmail.com");
                myMail.Fields.Add
                    ("http://schemas.microsoft.com/cdo/configuration/smtpserverport",
                                  "465");
                myMail.Fields.Add
                    ("http://schemas.microsoft.com/cdo/configuration/sendusing",
                                  "2");
                //sendusing: cdoSendUsingPort, value 2, for sending the message using 
                //the network.

                //smtpauthenticate: Specifies the mechanism used when authenticating 
                //to an SMTP 
                //service over the network. Possible values are:
                //- cdoAnonymous, value 0. Do not authenticate.
                //- cdoBasic, value 1. Use basic clear-text authentication. 
                //When using this option you have to provide the user name and password 
                //through the sendusername and sendpassword fields.
                //- cdoNTLM, value 2. The current process security context is used to 
                // authenticate with the service.
                myMail.Fields.Add
                ("http://schemas.microsoft.com/cdo/configuration/smtpauthenticate", "1");
                //Use 0 for anonymous
                myMail.Fields.Add
                ("http://schemas.microsoft.com/cdo/configuration/sendusername",
                    pGmailEmail);
                myMail.Fields.Add
                ("http://schemas.microsoft.com/cdo/configuration/sendpassword",
                     pGmailPassword);
                myMail.Fields.Add
                ("http://schemas.microsoft.com/cdo/configuration/smtpusessl",
                     "true");
                myMail.From = pGmailEmail;
                myMail.To = pTo;
                myMail.Bcc = pBcc;
                myMail.Subject = pSubject;
                myMail.BodyFormat = pFormat;
                myMail.Body = pBody;
                if (pAttachmentPath.Trim() != "")
                {
                    MailAttachment MyAttachment =
                            new MailAttachment(pAttachmentPath);
                    myMail.Attachments.Add(MyAttachment);
                    myMail.Priority = System.Web.Mail.MailPriority.High;
                }

                System.Web.Mail.SmtpMail.SmtpServer = "smtp.gmail.com:465";
                System.Web.Mail.SmtpMail.Send(myMail);

                return "Success";
            }
            catch (Exception ex)
            {
                return "Error: " + ex.ToString();
            }
        }
        #endregion



    }
}
