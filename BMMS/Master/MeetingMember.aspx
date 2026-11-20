<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="MeetingMember.aspx.cs" Inherits="BMMS.Master.MeetingMember"
    Title="Untitled Page" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="wb-page">
        <div class="wb-breadcrumb">
            Master<span class="wb-breadcrumb-sep">/</span>Meeting Member Tagging</div>
        <h1 class="wb-h1">
            Meeting Member Tagging</h1>
        <div aria-live="polite">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
        </div>
        <asp:Panel ID="pnlViewMeetingMember" runat="server">
            <div class="wb-card">
                <div class="wb-card-header">
                    Meeting members</div>
                <div class="wb-toolbar">
                    <div class="wb-filter">
                        <label for="ctl00_ContentPlaceHolder1_ddlCommittee">
                            Committee Name <span class="wb-req">*</span></label>
                        <asp:DropDownList ID="ddlCommittee" runat="server" AutoPostBack="true" OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                        </asp:DropDownList>
                    </div>
                    <div class="wb-filter">
                        <label for="ctl00_ContentPlaceHolder1_ddlMeeting">
                            Meeting No <span class="wb-req">*</span></label>
                        <asp:DropDownList ID="ddlMeeting" runat="server" AutoPostBack="true" OnSelectedIndexChanged="ddlMeeting_SelectedIndexChanged">
                        </asp:DropDownList>
                    </div>
                    <asp:Button ID="btnAdd" runat="server" CssClass="wb-btn" Text="Add" OnClick="btnAdd_Click" />
                </div>
                <div class="wb-table-scroll">
                    <asp:GridView ID="grvMeetingMember" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                        CssClass="wb-table" AllowSorting="true" DataKeyNames="MeetingMemberId" GridLines="None"
                        OnRowDataBound="grvMeetingMember_RowDataBound" OnSorting="grvRecord_Sorting" OnRowCommand="grvMeetingMember_RowCommand">
                        <Columns>
                            <asp:TemplateField HeaderText="S.No.">
                                <ItemTemplate>
                                    <%# Container.DataItemIndex+1 + "."%>
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="MeetingNo">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk1" runat="server" Text="Meeting No" CommandName="Sort" CommandArgument="MeetingNo"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblMeetingMemberCode" SkinID="lblSkinGen" Text='<%# HttpUtility.HtmlEncode(Eval("MeetingNo")) %>'
                                        runat="server" />
                                    <asp:HiddenField ID="hdnMeetingMemberCode" runat="server" />
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="MemberName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk2" runat="server" Text="Member Name" CommandName="Sort" CommandArgument="MemberName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblMemberName" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("MemberName")) %>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="DesignationName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnkDesignationName" runat="server" Text="Designation" CommandName="Sort"
                                        CommandArgument="DesignationName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblDesignationName" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("DesignationName")) %>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="MemberTypeName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk3" runat="server" Text="Member Type" CommandName="Sort" CommandArgument="MemberTypeName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblMemberTypeName" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("MemberTypeName")) %>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="StatusId">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk4" runat="server" Text="Status" CommandName="Sort" CommandArgument="StatusId"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblStatusId" runat="server" SkinID="lblskingen" Text='<%#Eval("StatusId").ToString() == "0" ? "InActive" : "Active" %>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnEdit" CssClass="wb-link-btn wb-link-edit" Text="Edit" ToolTip="Edit"
                                        CommandArgument='<%#Eval("MeetingMemberId")%>' runat="server" CommandName="EditRec" />
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnDelete" CssClass="wb-link-btn wb-link-delete" Text="Delete" ToolTip="Delete"
                                        CommandArgument='<%#Eval("MeetingMemberId")%>' runat="server" CommandName="DeleteRec"
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
                    Choose a committee and a meeting to list its members. Click a column heading to sort.
                    Delete asks for confirmation; a meeting member that is in use cannot be deleted.</p>
            </div>
        </asp:Panel>
        <asp:Panel ID="pnlEditMeetingMember" runat="server">
            <div class="wb-card">
                <div class="wb-card-header">
                    Meeting member details</div>
                <div class="wb-card-body wb-split">
                    <div class="wb-split-main">
                        <div class="wb-row">
                            <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtCommitteeName">
                                Committee Name</label>
                            <div class="wb-field">
                                <asp:TextBox ID="txtCommitteeName" runat="server" ReadOnly="true"></asp:TextBox>
                                <asp:HiddenField ID="hdnCommitteeId" runat="server" />
                            </div>
                        </div>
                        <div class="wb-row">
                            <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtMeetingNo">
                                Meeting No</label>
                            <div class="wb-field">
                                <asp:TextBox ID="txtMeetingNo" runat="server" ReadOnly="true"></asp:TextBox>
                                <asp:HiddenField ID="hdnMeetingId" runat="server" />
                                <asp:HiddenField ID="hdnMeetingMemberId" runat="server" />
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
