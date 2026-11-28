<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="AgendaApproval.aspx.cs" Inherits="BMMS.Report.AgendaApproval" Title="Agenda Approval" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <asp:Panel ID="pnlMeetingMaster" runat="server">
                <%-- Step UI2b: the Masters' form look (Committee Master): breadcrumb and title as in the menu, a Filter card and,
                     with Print, a Print details card with Create PDF as the primary button. The list stays outside .wb-page in
                     its old frame (R12). Control IDs, panels, events and the handlers are unchanged. --%>
                <div class="wb-page">
                    <div class="wb-breadcrumb">
                        Reports<span class="wb-breadcrumb-sep">/</span>Agenda Approval</div>
                    <h1 class="wb-h1">
                        Agenda Approval</h1>
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
                            <div class="wb-row">
                                <div class="wb-label">
                                    View Format</div>
                                <div class="wb-field">
                                    <asp:RadioButtonList ID="rdoViewFormat" runat="server" AutoPostBack="True" OnSelectedIndexChanged="rdoViewFormat_SelectedIndexChanged"
                                        RepeatDirection="Horizontal" CssClass="wb-radio-list">
                                        <asp:ListItem Text="View" Value="View" Selected="True"></asp:ListItem>
                                        <asp:ListItem Text="Print" Value="Print"></asp:ListItem>
                                    </asp:RadioButtonList>
                                </div>
                            </div>
                        </div>
                    </div>
                    <asp:Panel ID="pnlPrintReport" runat="server" Visible="false">
                        <div class="wb-card">
                            <div class="wb-card-header">
                                Print details</div>
                            <div class="wb-card-body">
                                <div class="wb-row">
                                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtMeetingVenue">
                                        Meeting Venue</label>
                                    <div class="wb-field">
                                        <asp:TextBox ID="txtMeetingVenue" runat="server" TextMode="MultiLine"></asp:TextBox>
                                    </div>
                                </div>
                                <div class="wb-row">
                                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtMeetingDate">
                                        Meeting Date</label>
                                    <div class="wb-field">
                                        <asp:TextBox ID="txtMeetingDate" runat="server"></asp:TextBox>
                                    </div>
                                </div>
                                <div class="wb-row">
                                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtMeetingTime">
                                        Meeting Time</label>
                                    <div class="wb-field">
                                        <asp:TextBox ID="txtMeetingTime" CssClass="txtTimeFormat" runat="server"></asp:TextBox>
                                        <span class="wb-unit">Hrs.</span>
                                    </div>
                                </div>
                                <div class="wb-actions">
                                    <asp:Button ID="btnCreatePDF" runat="server" Text="Create PDF" OnClick="btnCreatePDF_Click"
                                        CssClass="wb-btn" />
                                </div>
                                <asp:Panel ID="pnlAgendaDetailsDownload" runat="server" Visible="false">
                                    The agenda details opened in a new window; allow pop-ups if it did not.
                                </asp:Panel>
                            </div>
                        </div>
                    </asp:Panel>
                </div>
                <asp:Panel ID="pnlViewReport" runat="server">
                    <%-- Step UI2b (R12): the list keeps its frame and look; the frame is inside the panel --%>
                    <div class="formContent">
                        <div class="formPanel">
                            <div class="divRow">
                            <asp:GridView ID="grvAgendaDetails" runat="server" AutoGenerateColumns="false"
                                CssClass="contentTable1" AllowSorting="true" CellPadding="4" DataKeyNames="MeetingId"
                                Font-Names="Verdana, Arial, Helvetica, sans-serif" Font-Size="X-Small" ForeColor="#333333"
                                GridLines="Horizontal" Height="32px" Width="100%" OnSorting="grvRecord_Sorting">
                                <HeaderStyle CssClass="contentTableHeader" HorizontalAlign="Center" Font-Bold="true" />
                                <Columns>
                                    <asp:TemplateField HeaderText="S.No.">
                                        <ItemTemplate>
                                            <%# Container.DataItemIndex+1 + "."%>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                            Width="10px" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="MeetingNo">
                                        <HeaderTemplate>
                                            <asp:LinkButton runat="server" Text="Meeting No" CommandName="Sort"
                                                Style="color: White" CommandArgument="MeetingNo"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblMeetingNoe" SkinID="lblSkinGen" Text='<%#Eval("MeetingNo")%>' runat="server" />
                                            <asp:HiddenField ID="hdnMeetingNo" runat="server" />
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="MeetingDate">
                                        <HeaderTemplate>
                                            <asp:LinkButton runat="server" Text="Meeting Date / Time" CommandName="Sort"
                                                Style="color: White" CommandArgument="MeetingDate"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblMeetingDate" runat="server" SkinID="lblskingen" Text='<%#Eval("MeetingDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                            &nbsp; / &nbsp; 
                                            <asp:Label ID="lblMeetingTime" runat="server" SkinID="lblskingen" Text='<%#Eval("MeetingTime")%>'></asp:Label> Hrs.
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="AgendaNo">
                                        <HeaderTemplate>
                                            <asp:LinkButton runat="server" Text="Agenda No" CommandName="Sort"
                                                Style="color: White" CommandArgument="AgendaNo"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblAgendaNo" runat="server" SkinID="lblskingen" Text='<%#Eval("AgendaNo")%>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="SubjectNo">
                                        <HeaderTemplate>
                                            <asp:LinkButton runat="server" Text="Subject No" CommandName="Sort" Style="color: White"
                                                CommandArgument="SubjectNo"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblSubjectNo" runat="server" SkinID="lblskingen" Text='<%#Eval("SubjectNo")%>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="DepartmentName">
                                        <HeaderTemplate>
                                            <asp:LinkButton runat="server" CommandArgument="DepartmentName" CommandName="Sort"
                                                Style="color: White" Text="Department"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblDepartmentName" runat="server" SkinID="lblskingen" Text='<%#Eval("DepartmentName")%>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" HorizontalAlign="Left" VerticalAlign="Middle" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="AgendaStatusName">
                                        <HeaderTemplate>
                                            <asp:LinkButton ID="lnkAgendaStatusName" runat="server" CommandArgument="AgendaStatusName"
                                                CommandName="Sort" Style="color: White" Text="Agenda Status"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblAgendaStatusName" runat="server" SkinID="lblskingen" Text='<%#Eval("AgendaStatusName")%>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" HorizontalAlign="Left" VerticalAlign="Middle" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="ShortText">
                                        <HeaderTemplate>
                                            <asp:LinkButton runat="server" CommandArgument="ShortText" CommandName="Sort"
                                                Style="color: White" Text="Agenda Short Text"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblShortText" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("ShortText")) %>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" HorizontalAlign="Left" VerticalAlign="Middle" />
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
            </asp:Panel>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
