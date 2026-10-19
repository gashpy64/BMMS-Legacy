<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="MemberType.aspx.cs" Inherits="BMMS.Master.MemberType" Title="Untitled Page" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="wb-page">
        <div class="wb-breadcrumb">
            Master<span class="wb-breadcrumb-sep">/</span>Member Type Master</div>
        <h1 class="wb-h1">
            Member Type Master</h1>
        <div aria-live="polite">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
        </div>
        <asp:Panel ID="pnlViewMemberType" runat="server">
            <div class="wb-card">
                <div class="wb-card-header">
                    Member types</div>
                <div class="wb-toolbar">
                    <asp:Button ID="btnAdd" runat="server" CssClass="wb-btn" Text="Add" OnClick="btnAdd_Click" />
                </div>
                <div class="wb-table-scroll">
                    <asp:GridView ID="grvMemberType" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                        CssClass="wb-table" AllowSorting="true" DataKeyNames="MemberTypeId" GridLines="None"
                        OnRowDataBound="grvMemberType_RowDataBound" OnSorting="grvRecord_Sorting" OnRowCommand="grvMemberType_RowCommand">
                        <Columns>
                            <asp:TemplateField HeaderText="S.No.">
                                <ItemTemplate>
                                    <%# Container.DataItemIndex+1 + "."%>
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="MemberTypeCode">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk1" runat="server" Text="Member Type Code" CommandName="Sort"
                                        CommandArgument="MemberTypeCode"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblMemberTypeCode" SkinID="lblSkinGen" Text='<%#Eval("MemberTypeCode")%>'
                                        runat="server" />
                                    <asp:HiddenField ID="hdnMemberTypeCode" runat="server" />
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="MemberTypeName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk2" runat="server" Text="Member Type Name" CommandName="Sort"
                                        CommandArgument="MemberTypeName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblEmployeName" runat="server" SkinID="lblskingen" Text='<%#Eval("MemberTypeName")%>'></asp:Label>
                                    <asp:Label ID="lblReserved" runat="server" SkinID="lblskingen" Text=" (reserved)" Visible="false"></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="ScopeName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk3" runat="server" Text="Used On" CommandName="Sort" CommandArgument="ScopeName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblScopeName" runat="server" SkinID="lblskingen" Text='<%#Eval("ScopeName")%>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="DisplayOrder">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk5" runat="server" Text="Display Order" CommandName="Sort" CommandArgument="DisplayOrder"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblDisplayOrder" runat="server" SkinID="lblskingen" Text='<%#Eval("DisplayOrder")%>'></asp:Label>
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
                                        CommandArgument='<%#Eval("MemberTypeId")%>' runat="server" CommandName="EditRec" />
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnDelete" CssClass="wb-link-btn wb-link-delete" Text="Delete" ToolTip="Delete"
                                        CommandArgument='<%#Eval("MemberTypeId")%>' runat="server" CommandName="DeleteRec"
                                        OnClientClick="return confirm('Are you sure you want to delete this Record?');" />
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
                    Click a column heading to sort. "Used On" says which page offers the type: Committee
                    (Committee Member Tag / UnTag) or Meeting (Meeting - Member Tag / UnTag); each page lists
                    the active types in display order. Reserved types are used by the minutes and the notices
                    and cannot be changed or deleted. A type that is in use cannot be deleted or moved to the
                    other page; make it inactive instead. Delete asks for confirmation.</p>
            </div>
        </asp:Panel>
        <asp:Panel ID="pnlEditMemberType" runat="server">
            <div class="wb-card">
                <div class="wb-card-header">
                    Member type details</div>
                <div class="wb-card-body">
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtMemberTypeCode">
                            Member Type Code <span class="wb-req">*</span></label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtMemberTypeCode" runat="server" MaxLength="50"></asp:TextBox>
                            <asp:HiddenField ID="hdnMemberTypeId" runat="server" />
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtMemberTypeName">
                            Member Type Name <span class="wb-req">*</span></label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtMemberTypeName" runat="server" MaxLength="50"></asp:TextBox>
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlMemberScope">
                            Used On <span class="wb-req">*</span></label>
                        <div class="wb-field">
                            <asp:DropDownList ID="ddlMemberScope" runat="server">
                                <asp:ListItem Text="- Select -" Value="0"></asp:ListItem>
                                <asp:ListItem Text="Committee" Value="C"></asp:ListItem>
                                <asp:ListItem Text="Meeting" Value="M"></asp:ListItem>
                            </asp:DropDownList>
                            <asp:Label ID="lblScopeNote" runat="server" CssClass="wb-help" Visible="false"></asp:Label>
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtDisplayOrder">
                            Display Order</label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtDisplayOrder" runat="server" MaxLength="4"></asp:TextBox>
                            <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender1" runat="server" TargetControlID="txtDisplayOrder"
                                FilterMode="ValidChars" FilterType="Numbers" ValidChars="1234567890">
                            </cc1:FilteredTextBoxExtender>
                            <span class="wb-help">0 to 9999; lower numbers come first in the drop-downs and the minutes</span>
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
