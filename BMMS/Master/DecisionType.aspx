<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="DecisionType.aspx.cs" Inherits="BMMS.Master.DecisionType" Title="Untitled Page" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="wb-page">
        <div class="wb-breadcrumb">
            Master<span class="wb-breadcrumb-sep">/</span>Decision Type Master</div>
        <h1 class="wb-h1">
            Decision Type Master</h1>
        <div aria-live="polite">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
        </div>
        <asp:Panel ID="pnlViewDecisionType" runat="server">
            <div class="wb-card">
                <div class="wb-card-header">
                    Decision types</div>
                <%if (Session["RoleCode"].ToString() == "admin")
                  { %>
                <div class="wb-toolbar">
                    <asp:Button ID="btnAdd" runat="server" CssClass="wb-btn" Text="Add" OnClick="btnAdd_Click" />
                </div>
                <%
                    } %>
                <div class="wb-table-scroll">
                    <asp:GridView ID="grvDecisionType" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                        CssClass="wb-table" AllowSorting="true" DataKeyNames="DecisionTypeId" GridLines="None"
                        OnRowDataBound="grvDecisionType_RowDataBound" OnSorting="grvRecord_Sorting" OnRowCommand="grvDecisionType_RowCommand">
                        <Columns>
                            <asp:TemplateField HeaderText="S.No.">
                                <ItemTemplate>
                                    <%# Container.DataItemIndex+1 + "."%>
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="DecisionTypeCode">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk1" runat="server" Text="Decision Type Code" CommandName="Sort"
                                        CommandArgument="DecisionTypeCode"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblDecisionTypeCode" SkinID="lblSkinGen" Text='<%#Eval("DecisionTypeCode")%>'
                                        runat="server" />
                                    <asp:HiddenField ID="hdnDecisionTypeCode" runat="server" />
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="DecisionTypeName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk2" runat="server" Text="Decision Type Name" CommandName="Sort"
                                        CommandArgument="DecisionTypeName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblEmployeName" runat="server" SkinID="lblskingen" Text='<%#Eval("DecisionTypeName")%>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="StatusName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk4" runat="server" Text="Status" CommandName="Sort" CommandArgument="StatusName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblStatusName" runat="server" SkinID="lblskingen" Text='<%#Eval("StatusName")%>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnEdit" CssClass="wb-link-btn wb-link-edit" Text="Edit" ToolTip="Edit"
                                        CommandArgument='<%#Eval("DecisionTypeId")%>' runat="server" CommandName="EditRec" />
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnDelete" CssClass="wb-link-btn wb-link-delete" Text="Delete" ToolTip="Delete"
                                        CommandArgument='<%#Eval("DecisionTypeId")%>' runat="server" CommandName="DeleteRec"
                                        OnClientClick="return confirm('Are you sure you want to delete this UserRecord?');" />
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
                <p class="wb-help">
                    Click a column heading to sort. Delete asks for confirmation; a decision type that is
                    in use cannot be deleted.</p>
            </div>
        </asp:Panel>
        <asp:Panel ID="pnlEditDecisionType" runat="server">
            <div class="wb-card">
                <div class="wb-card-header">
                    Decision type details</div>
                <div class="wb-card-body">
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtDecisionTypeCode">
                            Decision Type Code</label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtDecisionTypeCode" runat="server" MaxLength="6" ReadOnly="true"></asp:TextBox>
                            <asp:HiddenField ID="hdnDecisionTypeId" runat="server" />
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtDecisionTypeName">
                            Decision Type Name <span class="wb-req">*</span></label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtDecisionTypeName" runat="server"></asp:TextBox>
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlStatus">
                            Status</label>
                        <div class="wb-field">
                            <asp:DropDownList ID="ddlStatus" runat="server">
                            </asp:DropDownList>
                        </div>
                    </div>
                    <div class="wb-actions">
                        <asp:Button ID="btnSave" runat="server" CssClass="wb-btn" Text="Save" OnClick="btnSave_Click" />
                        <asp:Button ID="btnCancel" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Cancel"
                            OnClick="btnCancel_Click" />
                    </div>
                </div>
            </div>
        </asp:Panel>
    </div>
</asp:Content>
