using System;
using System.Data;
using System.Configuration;
using System.Collections;
using System.Web;
using System.Web.Security;
using System.Web.SessionState;
using BMMSBAL;

namespace BMMS
{
    public class Global : System.Web.HttpApplication
    {

        protected void Application_Start(object sender, EventArgs e)
        {

        }

        protected void Application_End(object sender, EventArgs e)
        {

        }

        protected void Session_End(Object sender, EventArgs e)
        {
            if (Session["UserId"] != null)
            {
                int UserId = Convert.ToInt16(Session["UserId"].ToString());
                Utilities.AddEditAuditTrialLogin(UserId);
            }


        }

        #region Application_Error
        // The text of the safe error page (step E2); the guarded pages' Error/ErrorPage.aspx says the same
        private const string SafeErrorText = "This action could not be completed because of an error on the server. "
            + "The error is in the error log. Go back, then check what was saved before you try again.";

        // Step E2: an unhandled error that reaches the application (a page that posts back in full, an error
        // before the page starts such as request validation, a dangerous URL path with HTTP 400) is written once
        // to the error log and answered with a short fixed page: no exception text, no stack, no redirect, so an
        // error page can never loop. Untouched: HTTP 404 (not logged, the usual answer); the 404.8 of the hidden
        // folders and the 403 "Access denied" page of PageAccessModule never reach this handler. An UpdatePanel
        // postback gets status 500 with the fixed text, and JScript/AsyncPostBackError.js shows its message bar.
        // Never throws.
        protected void Application_Error(object sender, EventArgs e)
        {
            HttpContext context = Context;

            try
            {
                Exception error = Server.GetLastError();
                if (error == null)
                    return;

                HttpException httpError = error as HttpException;
                int status = httpError != null ? httpError.GetHttpCode() : 500;

                if (status == 404)
                    return;

                // Already logged by the E1 handler of an UpdatePanel postback: the ScriptManager's answer stands
                if (context.Items[Utilities.ErrorLoggedKey] != null)
                {
                    Server.ClearError();
                    return;
                }

                Utilities.LogUnhandledError(context, "Global", "Application_Error " + context.Request.HttpMethod, error);
                Server.ClearError();

                if (status < 400 || status > 599)
                    status = 500;

                WriteSafeAnswer(context, status);
            }
            catch (Exception)
            {
                WriteEmptyAnswer(context);
            }
        }

        private static void WriteSafeAnswer(HttpContext context, int status)
        {
            HttpResponse response = context.Response;

            try
            {
                // A download that failed half-way has set its own headers (Content-Disposition)
                if (!response.HeadersWritten)
                    response.ClearHeaders();
                response.Clear();
                response.TrySkipIisCustomErrors = true;
                response.StatusCode = status;

                string delta = context.Request.Headers["X-MicrosoftAjax"];
                if (delta != null && delta.IndexOf("Delta=true", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    response.ContentType = "text/plain";
                    response.Write(Utilities.AsyncPostBackErrorMessage);
                }
                else
                {
                    response.ContentType = "text/html";
                    response.Write(
                        "<!DOCTYPE html><html><head><meta charset=\"utf-8\" /><title>BMMS - Error</title></head>" +
                        "<body style=\"font-family:Arial,sans-serif;margin:40px\">" +
                        "<h3>Error</h3>" +
                        "<p>" + SafeErrorText + "</p>" +
                        "<p><a href=\"" + VirtualPathUtility.ToAbsolute("~/DashBoard/DashBoard.aspx") + "\">Back to home</a></p>" +
                        "</body></html>");
                }

                context.ApplicationInstance.CompleteRequest();
            }
            catch (Exception)
            {
                WriteEmptyAnswer(context);
            }
        }

        // The safe page could not be written: status 500, no body
        private static void WriteEmptyAnswer(HttpContext context)
        {
            try
            {
                context.Server.ClearError();
                context.Response.Clear();
                context.Response.StatusCode = 500;
                context.ApplicationInstance.CompleteRequest();
            }
            catch (Exception)
            {
            }
        }
        #endregion
    }
}