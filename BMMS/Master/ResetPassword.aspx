<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="ResetPassword.aspx.cs" Inherits="BMMS.Master.ResetPassword" Title="ResetPassword"
    ValidateRequest="false" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <asp:UpdateProgress ID="UpdateProgress1" runat="server">
                <ProgressTemplate>
                    <div class="divProgress">
                        <div class="divProgressBackground">
                        </div>
                        <div class="divProgressImg">
                            Loading ...</div>
                    </div>
                </ProgressTemplate>
            </asp:UpdateProgress>
            
            <div class="formContent">
                <div class="formPanel">
                    <div class="divHeader">
                :: Reset Password</div>
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
                            <div class="divRowLeft">
                                Login Name :
                            </div>
                            <div class="divRowRight">
                                <asp:DropDownList ID="ddlLoginUser" runat="server" Width="150px" AutoPostBack="true"
                                    OnSelectedIndexChanged="ddlLoginUser_SelectedIndexChanged">
                                </asp:DropDownList>
                                <br />
                                <div style="float: left; width: 75%; line-height: 20pt;">
                                    <asp:Literal ID="ltrlUserDetails" runat="server"></asp:Literal>
                                    <asp:HiddenField ID="hdnEmailId" runat="server" />
                                </div>
                                <div class="divRow">
                                    <asp:Panel ID="pnlResetPassword" runat="server">
                                        <div style="padding-top: 10px;">
                                            <asp:Button ID="btnResetPassword" runat="server" Text="Reset Password" CssClass="button"
                                                OnClick="btnResetPassword_Click" OnClientClick="return confirm('Are you sure to reset password?');" />
                                            <br />
                                        </div>
                                    </asp:Panel>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
