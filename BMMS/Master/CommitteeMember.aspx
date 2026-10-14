<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="CommitteeMember.aspx.cs" Inherits="BMMS.Master.CommitteeMember" MaintainScrollPositionOnPostback="true"
    Title="Untitled Page" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="wb-page">
        <div class="wb-breadcrumb">
            Master<span class="wb-breadcrumb-sep">/</span>Committee Member Tagging</div>
        <h1 class="wb-h1">
            Committee Member Tagging</h1>
        <div aria-live="polite">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
        </div>
        <asp:Panel ID="pnlViewCommitteeMember" runat="server">
            <div class="wb-card">
                <div class="wb-card-header">
                    Committee members</div>
                <div class="wb-toolbar">
                    <div class="wb-filter">
                        <label for="ctl00_ContentPlaceHolder1_ddlCommittee">
                            Committee Name <span class="wb-req">*</span></label>
                        <asp:DropDownList ID="ddlCommittee" runat="server" AutoPostBack="true" OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                        </asp:DropDownList>
                    </div>
                    <asp:Button ID="btnAdd" runat="server" CssClass="wb-btn" Text="Add" OnClick="btnAdd_Click" />
                </div>
                <div class="wb-table-scroll">
                    <asp:GridView ID="grvCommitteeMember" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                        CssClass="wb-table wb-table-wide" AllowSorting="true" DataKeyNames="CommitteeMemberId"
                        GridLines="None" OnRowDataBound="grvCommitteeMember_RowDataBound" OnSorting="grvRecord_Sorting"
                        OnRowCommand="grvCommitteeMember_RowCommand">
                        <Columns>
                            <asp:TemplateField HeaderText="S.No.">
                                <ItemTemplate>
                                    <%# Container.DataItemIndex+1 + "."%>
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="CommitteeName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk1" runat="server" Text="Committee Name" CommandName="Sort"
                                        CommandArgument="CommitteeName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblCommitteeMemberCode" SkinID="lblSkinGen" Text='<%#Eval("CommitteeName")%>'
                                        runat="server" />
                                    <asp:HiddenField ID="hdnCommitteeMemberCode" runat="server" />
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="MemberName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk2" runat="server" Text="Member Name" CommandName="Sort" CommandArgument="MemberName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblMemberName" runat="server" SkinID="lblskingen" Text='<%#Eval("MemberName")%>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="DesignationName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnkDesignationName" runat="server" Text="Designation" CommandName="Sort"
                                        CommandArgument="DesignationName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblDesignationName" runat="server" SkinID="lblskingen" Text='<%#Eval("DesignationName")%>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="MemberTypeName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk2" runat="server" Text="Member Type" CommandName="Sort" CommandArgument="MemberTypeName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblMemberTypeName" runat="server" SkinID="lblskingen" Text='<%#Eval("MemberTypeName")%>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="AppointmentDate">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk3" runat="server" Text="Appointment Date" CommandName="Sort"
                                        CommandArgument="AppointmentDate"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblAppointmentDate" runat="server" SkinID="lblskingen" Text='<%#Eval("AppointmentDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="CessationDate">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk4" runat="server" Text="Cessation Date" CommandName="Sort"
                                        CommandArgument="CessationDate"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblCessationDate" runat="server" SkinID="lblskingen" Text='<%#Eval("CessationDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="IsFeeApplicable">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk5" runat="server" Text="Is Fee Applicable" CommandName="Sort"
                                        CommandArgument="IsFeeApplicable"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblIsFeeApplicable" runat="server" SkinID="lblskingen" Text='<%#Eval("IsFeeApplicable").ToString() == "0" ? "No" : "Yes" %>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnEdit" CssClass="wb-link-btn wb-link-edit" Text="Edit" ToolTip="Edit"
                                        CommandArgument='<%#Eval("CommitteeMemberId")%>' runat="server" CommandName="EditRec" />
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnDelete" CssClass="wb-link-btn wb-link-delete" Text="Delete" ToolTip="Delete"
                                        CommandArgument='<%#Eval("CommitteeMemberId")%>' runat="server" CommandName="DeleteRec"
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
                    Choose a committee to list its members. Click a column heading to sort. Delete asks
                    for confirmation; a committee member that is in use cannot be deleted.</p>
            </div>
        </asp:Panel>
        <asp:Panel ID="pnlEditCommitteeMember" runat="server">
            <div class="wb-card">
                <div class="wb-card-header">
                    Committee member details</div>
                <div class="wb-card-body wb-split">
                    <div class="wb-split-main">
                        <div class="wb-row">
                            <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtCommitteeName">
                                Committee Name</label>
                            <div class="wb-field">
                                <asp:TextBox ID="txtCommitteeName" runat="server" ReadOnly="true"></asp:TextBox>
                                <asp:HiddenField ID="hdnCommitteeId" runat="server" />
                                <asp:HiddenField ID="hdnCommitteeMemberId" runat="server" />
                            </div>
                        </div>
                        <div class="wb-row">
                            <div class="wb-label">
                                Member Name <span class="wb-req">*</span></div>
                            <div class="wb-field">
                                <asp:DropDownList ID="ddlMemberName" runat="server" AutoPostBack="true" OnSelectedIndexChanged="ddlMemberName_SelectedIndexChanged">
                                </asp:DropDownList>
                                <asp:TextBox ID="txtMemberName" runat="server" ReadOnly="true"></asp:TextBox>
                                <asp:HiddenField ID="hdnMemberId" runat="server" />
                            </div>
                        </div>
                        <div class="wb-row">
                            <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlMemberType">
                                Member Type <span class="wb-req">*</span></label>
                            <div class="wb-field">
                                <asp:DropDownList ID="ddlMemberType" runat="server">
                                </asp:DropDownList>
                            </div>
                        </div>
                        <div class="wb-row">
                            <div class="wb-label">
                                Appointment Date <span class="wb-req">*</span></div>
                            <div class="wb-field">
                                <asp:TextBox ID="txtAppointmentDate" runat="server" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                                <asp:ImageButton runat="Server" ID="imgAppointmentDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender2" runat="server"
                                    TargetControlID="txtAppointmentDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                    PopupButtonID="imgAppointmentDate">
                                </cc1:CalendarExtender>
                            </div>
                        </div>
                        <div class="wb-row">
                            <div class="wb-label">
                                Cessation Date</div>
                            <asp:Panel ID="pnlCessationDate" runat="server" CssClass="wb-field">
                                <asp:TextBox ID="txtCessationDate" runat="server" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                                <asp:ImageButton runat="Server" ID="imgCessationDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender1" runat="server"
                                    TargetControlID="txtCessationDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                    PopupButtonID="imgCessationDate">
                                </cc1:CalendarExtender>
                            </asp:Panel>
                        </div>
                        <div class="wb-row">
                            <div class="wb-label">
                                Applicable Sitting Fees</div>
                            <div class="wb-field">
                                <asp:RadioButtonList ID="rdoIsFeeApplicable" runat="server" CssClass="wb-radio-list"
                                    AutoPostBack="True" OnSelectedIndexChanged="rdoIsFeeApplicable_SelectedIndexChanged"
                                    RepeatDirection="Horizontal">
                                    <asp:ListItem Text="Yes" Value="1"></asp:ListItem>
                                    <asp:ListItem Text="No" Value="0" Selected="True"></asp:ListItem>
                                </asp:RadioButtonList>
                            </div>
                        </div>
                        <div class="wb-row">
                            <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtApplicableFee">
                                Applicable Fee</label>
                            <div class="wb-field">
                                <asp:TextBox ID="txtApplicableFee" runat="server"></asp:TextBox>
                                <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender1" runat="server" TargetControlID="txtApplicableFee"
                                    FilterType="Custom" FilterMode="ValidChars" ValidChars="0123456789.">
                                </cc1:FilteredTextBoxExtender>
                            </div>
                        </div>
                        <div class="wb-actions">
                            <asp:Button ID="btnSave" runat="server" CssClass="wb-btn" Text="Save" OnClick="btnSave_Click" />
                            <asp:Button ID="btnCancel" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Cancel"
                                OnClick="btnCancel_Click" />
                        </div>
                    </div>
                    <div class="wb-aside">
                        <div class="divMemberDetails">
                            <asp:Literal ID="ltrlMemberDetails" runat="server"></asp:Literal>
                        </div>
                    </div>
                </div>
            </div>
        </asp:Panel>
    </div>
</asp:Content>
