<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="SittingFeesApplicable.aspx.cs" Inherits="BMMS.Report.SittingFeesApplicable"
    Title="Sitting Fees Applicable" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <asp:Panel ID="pnlSittingFeesApplicable" runat="server">
                <%-- Step UI2b: the Masters' form look (Committee Master): breadcrumb and title as in the menu, a card with
                     label and field rows, Submit as the primary button. Control IDs, events and the handlers are unchanged. --%>
                <div class="wb-page wb-page-fit">
                    <div class="wb-breadcrumb">
                        Reports<span class="wb-breadcrumb-sep">/</span>Sitting Fees Applicable</div>
                    <h1 class="wb-h1">
                        Sitting Fees Applicable</h1>
                    <div class="wb-card">
                        <div class="wb-card-header">
                            Filter</div>
                        <div class="wb-card-body">
                            <div class="wb-row">
                                <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlCommittee">
                                    Committee</label>
                                <div class="wb-field">
                                    <asp:DropDownList ID="ddlCommittee" runat="server" AutoPostBack="true"
                                        OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                                    </asp:DropDownList>
                                </div>
                            </div>
                            <div class="wb-row">
                                <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlMeeting">
                                    Meeting No</label>
                                <div class="wb-field">
                                    <asp:DropDownList ID="ddlMeeting" runat="server" AutoPostBack="true"
                                        OnSelectedIndexChanged="ddlMeeting_SelectedIndexChanged">
                                    </asp:DropDownList>
                                </div>
                            </div>
                            <div class="wb-actions">
                                <asp:Button ID="btnSubmit" runat="server" CssClass="wb-btn" Text="Submit" OnClick="btnSubmit_Click" />
                            </div>
                        </div>
                    </div>
                </div>
                <%-- Step UI2b (R12): the grid keeps its old frame and look, outside .wb-page --%>
                <div class="formContent">
                <div class="formPanel">
                    <div class="divRow">
                        <asp:GridView ID="grvSittingFeesApplicable" runat="server" SkinID="grvSkinNoPaging"
                            AutoGenerateColumns="false" CssClass="contentTable1" AllowSorting="true" CellPadding="4"
                            DataKeyNames="CommitteeId" Font-Names="Verdana, Arial, Helvetica, sans-serif"
                            Font-Size="X-Small" ForeColor="#333333" GridLines="Horizontal" Height="32px"
                            Width="100%" OnSorting="grvRecord_Sorting">
                            <HeaderStyle CssClass="contentTableHeader" HorizontalAlign="Center" Font-Bold="true" />
                            <Columns>
                                <asp:TemplateField HeaderText="S.No.">
                                    <ItemTemplate>
                                        <%# Container.DataItemIndex+1 + "."%>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                        Width="10px" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="CommitteeName">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Committee Name" CommandName="Sort" Style="color: White"
                                            CommandArgument="CommitteeName"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblCommitteeName" SkinID="lblSkinGen" Text='<%# HttpUtility.HtmlEncode(Eval("CommitteeName")) %>'
                                            runat="server" />
                                        <asp:HiddenField ID="hdnCommitteeId" runat="server" Value='<%#Eval("CommitteeId")%>' />
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="MeetingNo">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Meeting No" CommandName="Sort" Style="color: White"
                                            CommandArgument="MeetingNo"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblMeetingNoe" SkinID="lblSkinGen" Text='<%# HttpUtility.HtmlEncode(Eval("MeetingNo")) %>' runat="server" />
                                        <asp:HiddenField ID="hdnMeetingNo" runat="server" />
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="MeetingDate">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Meeting Date / Time" CommandName="Sort" Style="color: White"
                                            CommandArgument="MeetingDate"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblMeetingDate" runat="server" SkinID="lblskingen" Text='<%#Eval("MeetingDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                        &nbsp; / &nbsp;
                                        <asp:Label ID="lblMeetingTime" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("MeetingTime")) %>'></asp:Label> Hrs.
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="MemberTypeName">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Member Type" CommandName="Sort" Style="color: White"
                                            CommandArgument="MemberTypeName"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblMemberType" SkinID="lblSkinGen" Text='<%# HttpUtility.HtmlEncode(Eval("MemberTypeName")) %>'
                                            runat="server" />
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="MemberName">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Member Name" CommandName="Sort" Style="color: White"
                                            CommandArgument="MemberName"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblMemberName" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("MemberName")) %>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="DesignationName">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Designation" CommandName="Sort" Style="color: White"
                                            CommandArgument="DesignationName"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblDesignation" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("DesignationName")) %>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="Attendance">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Attendance" CommandName="Sort" Style="color: White"
                                            CommandArgument="Attendance"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblAttendance" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("Attendance")) %>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="ApplicableFee">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Sitting Fees" CommandName="Sort" Style="color: White"
                                            CommandArgument="ApplicableFee"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblSittingFees" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("SittingFees")) %>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
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
                </div>
            </asp:Panel>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
