<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="SystemSettings.aspx.cs" Inherits="BMMS.Master.SystemSettings" Title="System Settings" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="wb-page">
        <div class="wb-breadcrumb">
            Utilities<span class="wb-breadcrumb-sep">/</span>System Settings</div>
        <h1 class="wb-h1">
            System Settings</h1>
        <div aria-live="polite">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
        </div>
        <div class="wb-card">
            <div class="wb-card-header">
                Agenda</div>
            <div class="wb-card-body">
                <div class="wb-row">
                    <div class="wb-field">
                        <asp:CheckBox ID="chkAgendaControllerBypass" runat="server"
                            Text="Controller can add, edit and delete agenda items after the agenda is finalized" />
                    </div>
                </div>
                <p class="wb-help">
                    Applies until the minutes are finalized. Default: on.
                    <asp:Literal ID="litLastChanged" runat="server"></asp:Literal></p>
                <div class="wb-actions">
                    <asp:Button ID="btnSave" runat="server" CssClass="wb-btn" Text="Save" OnClick="btnSave_Click" />
                    <asp:Button ID="btnCancel" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Cancel"
                        OnClick="btnCancel_Click" />
                </div>
            </div>
        </div>
    </div>
</asp:Content>
