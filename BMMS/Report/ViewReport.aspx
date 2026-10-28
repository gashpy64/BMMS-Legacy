<%@ Page Language="C#" AutoEventWireup="true" Codebehind="ViewReport.aspx.cs"
    Inherits="BMMS.Report.ViewReport" %>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>Report</title>
    <link rel="icon" href="../favicon.ico" sizes="any" />
    <link rel="icon" type="image/png" sizes="192x192" href="../Images/Brand/bmms-favicon-192.png" />

    <script language="javascript" type="text/javascript" src="../JScript/BrowserSecurity.js"></script>
    <script language="javascript" type="text/javascript">
function printPartOfPage(elementClientId, myWidth)
            {
            window.print();
                //alert('ok);
//             var printContent = document.getElementById(elementClientId);
//             var windowUrl = 'about:blank';
//             var uniqueName = new Date();
//             var windowName = 'Print' + uniqueName.getTime();
//             var sFeatures = "center: yes; resizable: no; status: no; dialogHeight: " + 0 + "px; dialogWidth:" + myWidth + "px;"
//             var printWindow = window.showModalDialog(windowUrl, windowName, sFeatures);

//             printWindow.document.write("ppp");
//             printWindow.document.close();
//             printWindow.focus();
//             printWindow.print();
//             printWindow.close();
            }
            /* PRINT PART OF PAGE - START */

//            function printPartOfPage(elementClientId, myWidth)
//            {
//             var printContent = document.getElementById(elementClientId);
//             var windowUrl = 'about:blank';
//             var uniqueName = new Date();
//             var windowName = 'Print' + uniqueName.getTime();
//             var printWindow = window.open(windowUrl, windowName, 'left=0,top=0,width=0,height=0');

//             printWindow.document.write(printContent.innerHTML);
//             printWindow.document.close();
//             printWindow.focus();
//             printWindow.print();
//             printWindow.close();
//            }

            /* PRINT PART OF PAGE - END */
    </script>

    <%-- Print: the browser prints the report only (step 25). A floated element cannot start a new
         page, so the report's divs and tables are un-floated for print; the page-break divs
         (HTML_Report.HTML_PageBreak) then start each item on a new page. --%>
    <style type="text/css" media="print">
        .report-buttons, #GridView1 { display: none; }
        #pnlReport div, #pnlReport table { float: none !important; }
        #pnlReport div[style*="page-break-before"] { clear: both; display: block; }
    </style>

</head>
<body>
    <form id="form1" runat="server">
    <asp:GridView ID="GridView1" runat="server">
            </asp:GridView>
        <div>

            <div class="report-buttons">
            <asp:Button ID="btnPrint" runat="server" Text="Print" OnClientClick="window.print(); return false;" />
            <asp:Button ID="btnExportToWord" runat="server" Text="Export to Word" OnClick="btnExportToWord_Click" />
            <asp:Button ID="btnExportToPdf" runat="server" Text="Export to Pdf" OnClick="btnExportToPdf_Click" />
            <%-- Why Export to Pdf made no PDF (step U1b); not printed --%>
            <div id="divPdfMessage" runat="server" visible="false" style="margin-top: 6px; font-weight: bold; color: #9b1c1c;"></div>
            </div>

            
            
            <asp:Panel ID="pnlReport" runat="server">
                <asp:Literal ID="ltrlViewReport" runat="server"></asp:Literal>
            </asp:Panel>
           
        </div>
    </form>
</body>
</html>
