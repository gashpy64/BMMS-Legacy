<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="ResetDatabase.aspx.cs" Inherits="BMMS.Master.ResetDatabase" Title="ResetDatabase"
    ValidateRequest="true" %>

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
                :: Reset Database</div>
                <div class="divRowFixed"></div>
                <div style="text-align: center; padding-top: 100px;">
                    <asp:Button ID="btnResetDatabase" runat="server" Text="Reset Database" CssClass="button"
                        OnClick="btnResetDatabase_Click" OnClientClick="return confirm('This permanently deletes ALL records, including every user account and role. Sign-in will not work again until accounts are recreated. Continue?');" />
                </div>
            </div>
            </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
