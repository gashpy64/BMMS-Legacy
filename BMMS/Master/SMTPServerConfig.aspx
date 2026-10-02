<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="SMTPServerConfig.aspx.cs" Inherits="BMMS.Master.SMTPServerConfig"
    Title="SMTPServerConfig" ValidateRequest="false" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    
    <div class="formContent">
        <div class="formPanel">
            <div class="divHeader">
        :: SMTP Server Configuration</div>
            <div class="divRowFixed"></div>
            <div class="divRow">
                <div class="divRow">
                    <div class="divRowError" style="height: 35px;">
                        <div id="divErrLogin" runat="server" class="divErrorHide">
                            <span id="spanErrLogin" runat="server" class="lblError"></span>
                        </div>
                    </div>
                </div>
                <div class="divRow">
                    <div class="smtpconfiglbl">
                        SMTP Server :
                    </div>
                    <div class="divRowRight">
                        <asp:TextBox ID="txtSMTPServer" runat="server" Width="200px"></asp:TextBox>
                        <span class="spanMandatory">*</span>
                    </div>
                </div>
                <div class="divRow">
                    <div class="smtpconfiglbl">
                        SMTP Server Port :
                    </div>
                    <div class="divRowRight">
                        <asp:TextBox ID="txtSMTPServerPort" runat="server" Width="200px"></asp:TextBox>
                        <span class="spanMandatory">*</span>
                    </div>
                </div>
                <div class="divRow">
                    <div class="smtpconfiglbl">
                        User Name :
                    </div>
                    <div class="divRowRight">
                        <asp:TextBox ID="txtUserName" runat="server" Width="200px"></asp:TextBox>
                        <span class="spanMandatory">*</span>
                    </div>
                </div>
                <div class="divRow">
                    <div class="smtpconfiglbl">
                        Password :
                    </div>
                    <div class="divRowRight">
                        <asp:TextBox ID="txtPassword" runat="server" Width="200px" TextMode="Password"></asp:TextBox>
                        <asp:TextBox ID="txtPasswordDisplay" runat="server" Width="200px" Text="****************"></asp:TextBox>
                        <span class="spanMandatory">*</span>
                        <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender3" runat="server" TargetControlID="txtPassword"
                            InvalidChars=" .,;" FilterMode="InvalidChars" FilterType="Custom">
                        </cc1:FilteredTextBoxExtender>
                    </div>
                </div>
                <div class="divRow">
                    <div class="smtpconfiglbl">
                        From Mail Id :
                    </div>
                    <div class="divRowRight">
                        <asp:TextBox ID="txtFromMailId" runat="server" Width="200px"></asp:TextBox>
                        <span class="spanMandatory">*</span>
                    </div>
                </div>
                <div class="divRow">
                    <div class="smtpconfiglbl">
                        Bcc :
                    </div>
                    <div class="divRowRight">
                        <asp:TextBox ID="txtBcc" runat="server" Width="200px"></asp:TextBox>
                        <br />
                        <br />
                        <asp:Button ID="btnEdit" runat="server" Text="Edit" CssClass="button" OnClick="btnEdit_Click" Width="75px" />
                        <asp:Button ID="btnUpdate" runat="server" Text="Update" CssClass="button" OnClick="btnUpdate_Click" />
                        <asp:Button ID="btnCancel" runat="server" Text="Cancel" CssClass="button" OnClick="btnCancel_Click" />
                    </div>
                </div>
            </div>
        </div>
    </div>
</asp:Content>
