<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="User.aspx.cs" Inherits="BMMS.Master.User" Title="Untitled Page" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="wb-page">
        <div class="wb-breadcrumb">
            Master<span class="wb-breadcrumb-sep">/</span>User Master</div>
        <h1 class="wb-h1">
            User Master</h1>
        <div aria-live="polite">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
        </div>
        <asp:Panel ID="pnlViewUser" runat="server">
            <div class="wb-card">
                <div class="wb-card-header">
                    Users</div>
                <div class="wb-toolbar">
                    <asp:Button ID="btnAdd" runat="server" CssClass="wb-btn" Text="Add" OnClick="btnAdd_Click" />
                </div>
                <div class="wb-table-scroll">
                    <asp:GridView ID="grvUser" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                        CssClass="wb-table wb-table-wide" AllowSorting="true" DataKeyNames="UserId" GridLines="None"
                        OnRowDataBound="grvUser_RowDataBound" OnSorting="grvRecord_Sorting" OnRowCommand="grvUser_RowCommand">
                        <Columns>
                            <asp:TemplateField HeaderText="S.No.">
                                <ItemTemplate>
                                    <%# Container.DataItemIndex+1 + "."%>
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="UserName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk2" runat="server" Text="User Name" CommandName="Sort" CommandArgument="UserName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblEmployeName" runat="server" SkinID="lblskingen" Text='<%#Eval("UserName")%>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="DepartmentName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk3" runat="server" Text="Department Name" CommandName="Sort"
                                        CommandArgument="DepartmentName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblDepartmentName" runat="server" SkinID="lblskingen" Text='<%#Eval("DepartmentName")%>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="DesignationName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk4" runat="server" Text="Designation Name" CommandName="Sort"
                                        CommandArgument="DesignationName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblDesignationName" runat="server" SkinID="lblskingen" Text='<%#Eval("DesignationName")%>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="EmailId">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk5" runat="server" Text="Email Id" CommandName="Sort" CommandArgument="EmailId"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblEmailId" runat="server" SkinID="lblskingen" Text='<%#Eval("EmailId")%>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="RoleName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk6" runat="server" Text="Role Name" CommandName="Sort" CommandArgument="RoleName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblRoleName" runat="server" SkinID="lblskingen" Text='<%#Eval("RoleName")%>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="LoginName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk7" runat="server" Text="Login / User ID" CommandName="Sort"
                                        CommandArgument="LoginName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblLoginName" runat="server" SkinID="lblskingen" Text='<%#Eval("LoginName")%>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="Status">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk8" runat="server" Text="Status" CommandName="Sort" CommandArgument="Status"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblStatus" runat="server" CssClass="wb-status" Text='<%#Eval("Status")%>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnEdit" CssClass="wb-link-btn wb-link-edit" Text="Edit" ToolTip="Edit"
                                        CommandArgument='<%#Eval("UserId")%>' runat="server" CommandName="EditRec" />
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <%-- Text, CommandName and confirmation set in grvUser_RowDataBound (Deactivate / Activate) --%>
                                    <asp:Button ID="btnStatus" CssClass="wb-link-btn wb-link-status" Text="Deactivate" ToolTip="Deactivate"
                                        CommandArgument='<%#Eval("UserId")%>' runat="server" CommandName="DeactivateRec" />
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnDelete" CssClass="wb-link-btn wb-link-delete" Text="Delete" ToolTip="Delete"
                                        CommandArgument='<%#Eval("UserId")%>' runat="server" CommandName="DeleteRec"
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
                    Click a column heading to sort. Delete asks for confirmation; a user that is in use
                    cannot be deleted. Deactivate stops the user logging in and keeps them and their
                    history; Activate lets them log in again. Inactive users are shown greyed.</p>
            </div>
        </asp:Panel>
        <asp:Panel ID="pnlEditUser" runat="server">
            <div class="wb-card">
                <div class="wb-card-header">
                    User details</div>
                <div class="wb-card-body">
                    <div class="wb-section-title">
                        Profile</div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtUserName">
                            User Name <span class="wb-req">*</span></label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtUserName" runat="server"></asp:TextBox>
                            <asp:HiddenField ID="hdnUserId" runat="server" />
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlDepartment">
                            Department <span class="wb-req">*</span></label>
                        <div class="wb-field">
                            <asp:DropDownList ID="ddlDepartment" runat="server" AutoPostBack="True" OnSelectedIndexChanged="ddlDepartment_SelectedIndexChanged">
                            </asp:DropDownList>
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlRole">
                            Role <span class="wb-req">*</span></label>
                        <div class="wb-field">
                            <asp:DropDownList ID="ddlRole" runat="server" AutoPostBack="True" OnSelectedIndexChanged="ddlRole_SelectedIndexChanged">
                            </asp:DropDownList>
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlDesignation">
                            Designation <span class="wb-req">*</span></label>
                        <div class="wb-field">
                            <asp:DropDownList ID="ddlDesignation" runat="server">
                            </asp:DropDownList>
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlManager">
                            Reporting Person</label>
                        <div class="wb-field">
                            <asp:DropDownList ID="ddlManager" runat="server">
                            </asp:DropDownList>
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtEmailId">
                            Email Id <span class="wb-req">*</span></label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtEmailId" runat="server"></asp:TextBox>
                            <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender1" runat="server" TargetControlID="txtEmailId"
                                FilterMode="ValidChars" FilterType="Custom" ValidChars="abcdefghijklmnopqrstuvwxyz.@_">
                            </cc1:FilteredTextBoxExtender>
                        </div>
                    </div>
                    <div class="wb-section-title">
                        Login</div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtLoginName">
                            User ID <span class="wb-req">*</span></label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtLoginName" runat="server"></asp:TextBox>
                            <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender2" runat="server" TargetControlID="txtLoginName"
                                InvalidChars=" .;" FilterMode="InvalidChars" FilterType="Custom">
                            </cc1:FilteredTextBoxExtender>
                        </div>
                    </div>
                    <asp:Panel ID="pnlPwd" runat="server">
                        <div class="wb-row wb-row-strength">
                            <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtPassword">
                                Password <span class="wb-req">*</span></label>
                            <div class="wb-field">
                                <asp:TextBox ID="txtPassword" runat="server" TextMode="Password" oncopy="return false"
                                    oncut="return false" onpaste="return false"></asp:TextBox>
                                <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender3" runat="server" TargetControlID="txtPassword"
                                    InvalidChars=" .,;" FilterMode="InvalidChars" FilterType="Custom">
                                </cc1:FilteredTextBoxExtender>
                                <cc1:PasswordStrength ID="PasswordStrength1" runat="server" TargetControlID="txtPassword"
                                    DisplayPosition="BelowLeft" StrengthIndicatorType="Text" PreferredPasswordLength="6"
                                    PrefixText="Strength:" TextCssClass="TextIndicator_TextBox1" MinimumNumericCharacters="1"
                                    MinimumSymbolCharacters="1" RequiresUpperAndLowerCaseCharacters="true" TextStrengthDescriptions=" Poor; Weak; Good; Strong; Excellent"
                                    TextStrengthDescriptionStyles="textIndicator_poor; textIndicator_weak; textIndicator_good; textIndicator_strong; textIndicator_excellent"
                                    HelpHandlePosition="AboveLeft" CalculationWeightings="25;25;15;35">
                                </cc1:PasswordStrength>
                            </div>
                        </div>
                        <div class="wb-row">
                            <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtConfirmPassword">
                                Confirm Password <span class="wb-req">*</span></label>
                            <div class="wb-field">
                                <asp:TextBox ID="txtConfirmPassword" runat="server" TextMode="Password" oncopy="return false"
                                    oncut="return false" onpaste="return false"></asp:TextBox>
                                <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender4" runat="server" TargetControlID="txtConfirmPassword"
                                    InvalidChars=" .,;" FilterMode="InvalidChars" FilterType="Custom">
                                </cc1:FilteredTextBoxExtender>
                            </div>
                        </div>
                        <div class="wb-row">
                            <div class="wb-label">
                            </div>
                            <div class="wb-field">
                                <span class="wb-unit">Password length minimum of 6 characters in length. The password
                                    should contain combination of UpperCase, LowerCase, Number and Special Character.</span>
                            </div>
                        </div>
                    </asp:Panel>
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
