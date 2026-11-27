<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="MinutesFinalization.aspx.cs" Inherits="BMMS.Master.MinutesFinalization"
    Title="Untitled Page" ValidateRequest="false" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <%-- Step UI2a: the Masters' form look (Committee Master): breadcrumb and title as in the menu, a card with label
         and field rows, Finalize as the primary button and Cancel as the secondary one. Control IDs, events and the
         confirmation are unchanged. --%>
    <div class="wb-page">
        <div class="wb-breadcrumb">
            Minutes<span class="wb-breadcrumb-sep">/</span>Finalize Minutes</div>
        <h1 class="wb-h1">
            Finalize Minutes</h1>
        <div aria-live="polite">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
        </div>
        <asp:Panel ID="pnlMinutesFinalize" runat="server">
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
                            <asp:DropDownList ID="ddlMeeting" runat="server" AutoPostBack="true"
                                OnSelectedIndexChanged="ddlMeeting_SelectedIndexChanged">
                            </asp:DropDownList>
                        </div>
                    </div>
                    <div class="wb-actions">
                        <asp:Button ID="btnFinalize" runat="server" CssClass="wb-btn" Text="Finalize" OnClick="btnFinalize_Click"
                            OnClientClick="return confirm('Do you want to Finalize this Meeting Minutes?');" />
                        <asp:Button ID="btnCancel" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Cancel" OnClick="btnCancel_Click" />
                    </div>
                </div>
            </div>
            <%-- Step MF1 (D1): the meeting's items, read only, as the Agenda Finalize list (wb-table). Shown when a
                 committee and a meeting are chosen, hidden again when either goes back to -Select- or changes. Each
                 cell is plain text from MinutesMgr.GetMinutesItemList, encoded once here. --%>
            <asp:Panel ID="pnlMinutesItems" runat="server" Visible="false">
                <div class="wb-card">
                    <div class="wb-card-header">
                        Minutes Items</div>
                    <div class="wb-table-scroll">
                        <asp:GridView ID="grvMinutesItems" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                            CssClass="wb-table" GridLines="None" EnableViewState="false">
                            <Columns>
                                <asp:TemplateField HeaderText="Agenda No">
                                    <ItemTemplate>
                                        <%# HttpUtility.HtmlEncode(Eval("AgendaNo")) %>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="wb-col-action" />
                                </asp:TemplateField>
                                <asp:TemplateField HeaderText="Subject No">
                                    <ItemTemplate>
                                        <%# HttpUtility.HtmlEncode(Eval("SubjectNo")) %>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="wb-col-action" />
                                </asp:TemplateField>
                                <asp:TemplateField HeaderText="Short Text">
                                    <ItemTemplate>
                                        <%# HttpUtility.HtmlEncode(Eval("ShortText")) %>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="wb-col-text" />
                                </asp:TemplateField>
                                <asp:TemplateField HeaderText="Decision">
                                    <ItemTemplate>
                                        <%# HttpUtility.HtmlEncode(Eval("Decision")) %>
                                    </ItemTemplate>
                                </asp:TemplateField>
                                <asp:TemplateField HeaderText="Actual Resolution">
                                    <ItemTemplate>
                                        <%# HttpUtility.HtmlEncode(Eval("ActualResolution")) %>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="wb-col-text" />
                                </asp:TemplateField>
                            </Columns>
                            <EmptyDataTemplate>
                                <div class="divNoRecord">
                                    No items in this meeting.</div>
                            </EmptyDataTemplate>
                        </asp:GridView>
                    </div>
                </div>
            </asp:Panel>
        </asp:Panel>
    </div>
</asp:Content>
