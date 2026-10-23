<%@ Page Language="C#" AutoEventWireup="true" Codebehind="Default.aspx.cs" Inherits="BMMS._Default"
    Trace="false" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
    <title></title>
    <link href="CSS/CommonHTML.css" rel="stylesheet" type="text/css" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <link href="CSS/bmms-workbench.css" rel="stylesheet" type="text/css" />

    <script type="text/javascript" language="javascript" src="JScript/BrowserSecurity.js"></script>

</head>
<body class="wb">
    <form id="form1" runat="server">
        <asp:ScriptManager ID="ScriptManager1" runat="server" OnAsyncPostBackError="ScriptManager1_AsyncPostBackError">
            <Scripts>
                <asp:ScriptReference Path="~/JScript/Validation.js" />
                <asp:ScriptReference Path="~/JScript/AsyncPostBackError.js" />
            </Scripts>
        </asp:ScriptManager>
        <asp:UpdatePanel ID="UpdatePanel1" runat="server">
            <ContentTemplate>
                <div class="wb-page wb-login">
                    <h1 class="wb-h1">BMMS</h1>
                    <p class="wb-help" style="text-align: center;">Board Minutes and Meeting Software</p>
                    <%-- A failed UpdatePanel postback (JScript/AsyncPostBackError.js, step E1) --%>
                    <div id="wbAsyncError" class="wb-async-error" role="alert" style="display: none;"></div>
                    <div class="wb-card">
                        <div class="wb-card-header">
                            Log in</div>
                        <div class="wb-card-body">
                            <div aria-live="polite">
                                <div id="divErrLogin" runat="server" class="divErrorHide">
                                    <span id="spanErrLogin" runat="server" class="lblError"></span>
                                </div>
                            </div>
                            <div class="wb-row">
                                <label class="wb-label" for="txtLoginName">
                                    User ID</label>
                                <div class="wb-field">
                                    <asp:TextBox ID="txtLoginName" runat="server"></asp:TextBox>
                                    <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender1" runat="server" TargetControlID="txtLoginName"
                                        InvalidChars=" .;" FilterMode="InvalidChars" FilterType="Custom">
                                    </cc1:FilteredTextBoxExtender>
                                </div>
                            </div>
                            <div class="wb-row">
                                <label class="wb-label" for="txtPassword">
                                    Password</label>
                                <div class="wb-field">
                                    <asp:TextBox ID="txtPassword" TextMode="Password" runat="server" oncopy="return false"
                                        oncut="return false" onpaste="return false"></asp:TextBox>
                                    <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender2" runat="server" TargetControlID="txtPassword"
                                        InvalidChars=" .;" FilterMode="InvalidChars" FilterType="Custom">
                                    </cc1:FilteredTextBoxExtender>
                                </div>
                            </div>
                            <div class="wb-actions">
                                <asp:ImageButton ID="btnLogin" runat="server" AlternateText="Log in" ImageUrl="~/Images/login-btn-workbench.svg"
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
