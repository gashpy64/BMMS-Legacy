<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="AgendaFinalization.aspx.cs" Inherits="BMMS.Master.AgendaFinalization"
    Title="Untitled Page" ValidateRequest="false" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <%-- Step UI2a: the Masters' form look (Committee Master): breadcrumb and title as in the menu, a card with
                 label and field rows, Finalize as the primary button and Cancel as the secondary one. Control IDs,
                 events and the confirmation are unchanged. --%>
            <div class="wb-page">
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
                <div class="wb-breadcrumb">
                    Agenda<span class="wb-breadcrumb-sep">/</span>Agenda Finalize</div>
                <h1 class="wb-h1">
                    Agenda Finalize</h1>
                <div aria-live="polite">
                    <div id="divErrLogin" runat="server" class="divErrorHide">
                        <span id="spanErrLogin" runat="server" class="lblError"></span>
                    </div>
                </div>
                <asp:Panel ID="pnlAgendaFinalize" runat="server">
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
                                    OnClientClick="return confirm('Do you want to Finalize this Meeting Agenda?');" />
                                <asp:Button ID="btnCancel" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Cancel" OnClick="btnCancel_Click" />
                            </div>
                        </div>
                    </div>
                    <%-- Step UI2a (D5): the pending agenda items as a Masters list (wb-table). Sorting and the Visible
                         rule of pnlPendingAgenda (code-behind) are unchanged. Owner test G1: no Committee Name and
                         Meeting No columns (they repeat the choice above); the mail still reads them from the data. --%>
                    <asp:Panel ID="pnlPendingAgenda" runat="server" Visible="false">
                        <div class="wb-card">
                            <div class="wb-card-header">
                                Pending Agenda Details</div>
                            <div class="wb-table-scroll">
                                <asp:GridView ID="grvAgenda" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                                    CssClass="wb-table" AllowSorting="true" DataKeyNames="AgendaId" GridLines="None"
                                    OnRowDataBound="grvAgenda_RowDataBound" OnSorting="grvRecord_Sorting">
                                    <Columns>
                                        <asp:TemplateField HeaderText="S.No.">
                                            <ItemTemplate>
                                                <%# Container.DataItemIndex+1 + "."%>
                                            </ItemTemplate>
                                            <ItemStyle CssClass="wb-col-action" />
                                        </asp:TemplateField>
                                        <asp:TemplateField SortExpression="AgendaNo">
                                            <HeaderTemplate>
                                                <asp:LinkButton ID="lnk1" runat="server" Text="Agenda No" CommandName="Sort"
                                                    CommandArgument="AgendaNo"></asp:LinkButton>
                                            </HeaderTemplate>
                                            <ItemTemplate>
                                                <asp:Label ID="lblAgendaNo" SkinID="lblSkinGen" Text='<%#Eval("AgendaNo")%>' runat="server" />
                                                <asp:HiddenField ID="hdnAgendaId" runat="server" />
                                            </ItemTemplate>
                                            <ItemStyle CssClass="wb-col-action" />
                                        </asp:TemplateField>
                                        <asp:TemplateField SortExpression="SubjectTypeName">
                                            <HeaderTemplate>
                                                <asp:LinkButton ID="lnk4" runat="server" Text="Subject Type Name" CommandName="Sort"
                                                    CommandArgument="SubjectTypeName"></asp:LinkButton>
                                            </HeaderTemplate>
                                            <ItemTemplate>
                                                <asp:Label ID="lblSubjectTypeName" runat="server" SkinID="lblskingen" Text='<%#Eval("SubjectTypeName") %>'></asp:Label>
                                            </ItemTemplate>
                                        </asp:TemplateField>
                                        <asp:TemplateField SortExpression="ShortText">
                                            <HeaderTemplate>
                                                <asp:LinkButton ID="lnk5" runat="server" Text="Short Text" CommandName="Sort"
                                                    CommandArgument="ShortText"></asp:LinkButton>
                                            </HeaderTemplate>
                                            <ItemTemplate>
                                                <asp:Label ID="lblShortText" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("ShortText")) %>'></asp:Label>
                                            </ItemTemplate>
                                        </asp:TemplateField>
                                        <asp:TemplateField SortExpression="AgendaStatusName">
                                            <HeaderTemplate>
                                                <asp:LinkButton ID="lnk6" runat="server" Text="Agenda Status" CommandName="Sort"
                                                    CommandArgument="AgendaStatusName"></asp:LinkButton>
                                            </HeaderTemplate>
                                            <ItemTemplate>
                                                <asp:Label ID="lblAgendaStatusName" runat="server" SkinID="lblskingen" Text='<%#Eval("AgendaStatusName") %>'></asp:Label>
                                            </ItemTemplate>
                                            <ItemStyle CssClass="wb-col-action" />
                                        </asp:TemplateField>
                                    </Columns>
                                    <EmptyDataTemplate>
                                        <div class="divNoRecord">
                                            <%#Session["NoRecord"].ToString()%>
                                        </div>
                                    </EmptyDataTemplate>
                                </asp:GridView>
                            </div>
                        </div>
                    </asp:Panel>
                </asp:Panel>
            </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
