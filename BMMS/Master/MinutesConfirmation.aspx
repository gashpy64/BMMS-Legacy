<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="MinutesConfirmation.aspx.cs" Inherits="BMMS.Master.MinutesConfirmation"
    Title="Minutes Confirmation" ValidateRequest="false" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <%-- Step UI2a: the Masters' form look (Committee Master): breadcrumb and title as in the menu, a card with label
         and field rows, Confirm as the primary button and Cancel as the secondary one. Control IDs, events and the
         confirmation are unchanged. --%>
    <div class="wb-page">
        <div class="wb-breadcrumb">
            Minutes<span class="wb-breadcrumb-sep">/</span>Minutes Confirmation</div>
        <h1 class="wb-h1">
            Minutes Confirmation</h1>
        <div aria-live="polite">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
        </div>
        <asp:Panel ID="pnlMinutesConfirm" runat="server">
            <div class="wb-card">
                <div class="wb-card-header">
                    Meeting</div>
                <div class="wb-card-body">
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlCommittee">
                            Committee Name <span class="wb-req">*</span></label>
                        <div class="wb-field">
                            <asp:DropDownList ID="ddlCommittee" runat="server" AutoPostBack="true"
                                OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                            </asp:DropDownList>
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlMeeting">
                            Meeting No <span class="wb-req">*</span></label>
                        <div class="wb-field">
                            <asp:DropDownList ID="ddlMeeting" runat="server" AutoPostBack="true">
                            </asp:DropDownList>
                        </div>
                    </div>
                    <div class="wb-actions">
                        <asp:Button ID="btnConfirm" runat="server" CssClass="wb-btn" Text="Confirm" OnClick="btnConfirm_Click"
                            OnClientClick="return confirm('Do you want to Confirm this Meeting Minutes?');" />
                        <asp:Button ID="btnCancel" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Cancel" OnClick="btnCancel_Click" />
                    </div>
                </div>
            </div>
        </asp:Panel>
    </div>
</asp:Content>
