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
    <link href="CSS/bmms-colours.css" rel="stylesheet" type="text/css" />
    <link href="CSS/bmms-workbench.css" rel="stylesheet" type="text/css" />
    <link rel="icon" href="favicon.ico" sizes="any" />
    <link rel="icon" type="image/png" sizes="192x192" href="Images/Brand/bmms-favicon-192.png" />

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
        <%-- The login banner (step B3): up to 560 px wide, scales down with the window; it shows the
             product name, so the heading below is for screen readers only --%>
        <div class="wb-login-banner">
            <img src="<%= ResolveUrl("~/Images/Brand/bmms-login-banner.png") %>" srcset="<%= ResolveUrl("~/Images/Brand/bmms-login-banner-2x.png") %> 2x"
                width="1000" height="240" alt="" />
        </div>
        <asp:UpdatePanel ID="UpdatePanel1" runat="server">
            <ContentTemplate>
                <div class="wb-page wb-login">
                    <h1 class="wb-h1 wb-visually-hidden">BMMS</h1>
                    <p class="wb-visually-hidden">Board Minutes and Meeting Software</p>
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
        <%-- the footer line of the other pages (step B3) --%>
        <div id="footer">
            <asp:Label ID="lblFooter" runat="server"></asp:Label>
        </div>
    </form>
</body>
</html>
