<%@ Page Language="C#" AutoEventWireup="true" Codebehind="ReportPrint.aspx.cs"
    Inherits="BMMS.Report.ReportPrint" %>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>Report</title>
</head>
<body onload="window.print();window.close();">
    <form id="form1" runat="server">
        <div>
            <asp:Panel ID="pnlReport" runat="server">
                <asp:Literal ID="ltrlReportPrint" runat="server" Text="-"></asp:Literal>
            </asp:Panel>
        </div>
    </form>
</body>
</html>
