<%@ Page Language="C#" AutoEventWireup="true" Codebehind="Default.aspx.cs" Inherits="BMMS._Default"
    Trace="false" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
    <title></title>
    <link href="CSS/CommonHTML.css" rel="stylesheet" type="text/css" />
    <link href="CSS/LoginPage.css" rel="stylesheet" type="text/css" />

    <script type="text/javascript" language="javascript" src="JScript/BrowserSecurity.js"></script>

</head>
<body>
    <form id="form1" runat="server">
        <asp:ScriptManager ID="ScriptManager1" runat="server">
            <Scripts>
                <asp:ScriptReference Path="~/JScript/Validation.js" />
            </Scripts>
        </asp:ScriptManager>
        <asp:UpdatePanel ID="UpdatePanel1" runat="server">
            <ContentTemplate>
                <div id="wrapper" >
                    <div id="logo">
                        &nbsp;</div>
                    <div id="loginBox">
                        <div class="divRow">
                            <div class="divRowError" style="height: 35px; margin-left: -110px; margin-top: -30px;">
                                <div id="divErrLogin" runat="server" class="divErrorHide">
                                    <span id="spanErrLogin" runat="server" class="lblError"></span>
                                </div>
                            </div>
                            <div class="divRow" style="height: 32px;">
                                <asp:TextBox ID="txtLoginName" runat="server" Width="150px"></asp:TextBox>
                                <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender1" runat="server" TargetControlID="txtLoginName"
                                    InvalidChars=" .;" FilterMode="InvalidChars" FilterType="Custom">
                                </cc1:FilteredTextBoxExtender>
                            </div>
                            <div class="divRow">
                                <asp:TextBox ID="txtPassword" TextMode="Password" runat="server" Width="150px" oncopy="return false"
                                    oncut="return false" onpaste="return false"></asp:TextBox>
                                <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender2" runat="server" TargetControlID="txtPassword"
                                    InvalidChars=" .;" FilterMode="InvalidChars" FilterType="Custom">
                                </cc1:FilteredTextBoxExtender>
                            </div>
                            <div class="divRow">
                                <asp:ImageButton ID="btnLogin" runat="server" AlternateText="" ImageUrl="~/Images/login-btn.gif"
                                    OnClick="btnLogin_Click" />
                            </div>
                        </div>
                    </div>
                </div>
            </ContentTemplate>
        </asp:UpdatePanel>
    </form>
</body>
</html>
