<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="Department.aspx.cs" Inherits="BMMS.Master.Department" Title="Untitled Page" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="wb-page">
        <div class="wb-breadcrumb">
            Master<span class="wb-breadcrumb-sep">/</span>Department Master</div>
        <h1 class="wb-h1">
            Department Master</h1>
        <div aria-live="polite">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
        </div>
        <asp:Panel ID="pnlViewDept" runat="server">
            <div class="wb-card">
                <div class="wb-card-header">
                    Departments</div>
                <div class="wb-toolbar">
                    <asp:Button ID="btnAdd" runat="server" CssClass="wb-btn" Text="Add" OnClick="btnAdd_Click" />
                </div>
                <div class="wb-table-scroll">
                    <asp:GridView ID="grvDepartment" runat="server" AutoGenerateColumns="false" CssClass="wb-table"
                        AllowSorting="true" AllowPaging="true" DataKeyNames="DepartmentId" GridLines="None"
                        OnRowDataBound="grvDepartment_RowDataBound" OnSorting="grvRecord_Sorting" OnRowCommand="grvDepartment_RowCommand"
                        OnPageIndexChanging="OnPaging" PageSize="10">
                        <PagerStyle CssClass="wb-pager" />
                        <Columns>
                            <asp:TemplateField HeaderText="S.No.">
                                <ItemTemplate>
                                    <%# Container.DataItemIndex+1 + "."%>
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="DepartmentCode">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk1" runat="server" Text="Department Code" CommandName="Sort"
                                        CommandArgument="DepartmentCode"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblDepartmentCode" SkinID="lblSkinGen" Text='<%# HttpUtility.HtmlEncode(Eval("DepartmentCode")) %>'
                                        runat="server" />
                                    <asp:HiddenField ID="hdnDepartmentCode" runat="server" />
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="DepartmentName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk2" runat="server" Text="Department Name" CommandName="Sort"
                                        CommandArgument="DepartmentName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblEmployeName" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("DepartmentName")) %>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="OrderNo">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk3" runat="server" Text="Display Order" CommandName="Sort"
                                        CommandArgument="OrderNo"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblOrderNo" runat="server" SkinID="lblskingen" Text='<%#Eval("OrderNo")%>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="StatusName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk4" runat="server" Text="Status" CommandName="Sort" CommandArgument="StatusName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblStatusName" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("StatusName")) %>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnEdit" CssClass="wb-link-btn wb-link-edit" Text="Edit" ToolTip="Edit"
                                        CommandArgument='<%#Eval("DepartmentId")%>' runat="server" CommandName="EditRec" />
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnDelete" CssClass="wb-link-btn wb-link-delete" Text="Delete" ToolTip="Delete"
                                        CommandArgument='<%#Eval("DepartmentId")%>' runat="server" CommandName="DeleteRec"
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
                    Click a column heading to sort. Delete asks for confirmation; a department that is
                    in use cannot be deleted.</p>
            </div>
        </asp:Panel>
        <asp:Panel ID="pnlEditDept" runat="server">
            <div class="wb-card">
                <div class="wb-card-header">
                    Department details</div>
                <div class="wb-card-body">
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtDeptCode">
                            Department Code</label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtDeptCode" runat="server" MaxLength="6" ReadOnly="true"></asp:TextBox>
                            <asp:HiddenField ID="hdnDeptId" runat="server" />
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtDeptName">
                            Department Name <span class="wb-req">*</span></label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtDeptName" runat="server"></asp:TextBox>
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtOrderNo">
                            Display Order No <span class="wb-req">*</span></label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtOrderNo" runat="server" MaxLength="3"></asp:TextBox>
                            <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender1" runat="server" TargetControlID="txtOrderNo"
                                FilterMode="ValidChars" FilterType="Numbers" ValidChars="1234567890">
                            </cc1:FilteredTextBoxExtender>
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
