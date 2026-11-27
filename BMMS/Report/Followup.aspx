<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="Followup.aspx.cs" Inherits="BMMS.Report.Followup" Title="Untitled Page" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
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
            <asp:Panel ID="pnlMeetingMaster" runat="server">
                <%-- Step UI2b: the Masters' form look (Committee Master), as Minutes > Followup in UI2a: breadcrumb and
                     title as in the menu (the text of lblPageHeader, set from the query string in Page_Load), one
                     column of label and field rows, View as the primary button and Generate and Cancel as the
                     secondary ones, in today's order (D8). The list stays outside .wb-page in its old frame (R12).
                     Control IDs, events and the handlers are unchanged. --%>
                <div class="wb-page">
                    <div class="wb-breadcrumb">
                        Reports<span class="wb-breadcrumb-sep">/</span><%: lblPageHeader.Text %></div>
                    <h1 class="wb-h1">
                        <asp:Label ID="lblPageHeader" runat="server" Text=""></asp:Label></h1>
                    <div aria-live="polite">
                        <div id="divErrLogin" runat="server" class="divErrorHide">
                            <span id="spanErrLogin" runat="server" class="lblError"></span>
                        </div>
                    </div>
                    <asp:Panel ID="pnlFollowupFilter" runat="server">
                        <div class="wb-card">
                            <div class="wb-card-header">
                                Filter</div>
                            <div class="wb-card-body">
                                <div class="wb-row">
                                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtFromDate">
                                        Meeting Date From <span class="wb-req">*</span></label>
                                    <div class="wb-field">
                                        <asp:TextBox ID="txtFromDate" runat="server" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                                        <asp:ImageButton runat="Server" ID="imgFromDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                        <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender1" runat="server"
                                            TargetControlID="txtFromDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                            PopupButtonID="imgFromDate">
                                        </cc1:CalendarExtender>
                                        <span class="wb-unit">to</span>
                                        <asp:TextBox ID="txtToDate" runat="server" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                                        <asp:ImageButton runat="Server" ID="imgToDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                        <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender2" runat="server"
                                            TargetControlID="txtToDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                            PopupButtonID="imgToDate">
                                        </cc1:CalendarExtender>
                                    </div>
                                </div>
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
                                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlDepartment">
                                        Department</label>
                                    <div class="wb-field">
                                        <asp:DropDownList ID="ddlDepartment" runat="server">
                                        </asp:DropDownList>
                                    </div>
                                </div>
                                <div class="wb-row">
                                    <div class="wb-label">
                                        Meeting No. Search</div>
                                    <div class="wb-field">
                                        <asp:RadioButtonList ID="rdoMeatingNoSearch" runat="server" RepeatDirection="Horizontal"
                                            CssClass="wb-radio-list" AutoPostBack="true" OnSelectedIndexChanged="rdoMeatingNoSearch_SelectedIndexChanged">
                                            <asp:ListItem Text="Particular" Value="0" Selected="True"></asp:ListItem>
                                            <asp:ListItem Text="Between" Value="1"></asp:ListItem>
                                        </asp:RadioButtonList>
                                    </div>
                                </div>
                                <div class="wb-row">
                                    <div class="wb-label">
                                        Meeting No.</div>
                                    <div class="wb-field">
                                        <asp:Panel ID="pnlMeetingNoParticular" runat="server">
                                            <asp:DropDownList ID="ddlMeetingNo" runat="server" CssClass="wb-filter-select wb-filter-meetno">
                                            </asp:DropDownList>
                                        </asp:Panel>
                                        <asp:Panel ID="pnlMeetingNoBetween" runat="server">
                                            <asp:DropDownList ID="ddlMeetingNoFrom" runat="server" CssClass="wb-filter-select wb-filter-meetno">
                                            </asp:DropDownList>
                                            <asp:Label ID="lblMeetingNo" runat="server" CssClass="wb-unit" Text=" to "></asp:Label>
                                            <asp:DropDownList ID="ddlMeetingNoTo" runat="server" CssClass="wb-filter-select wb-filter-meetno">
                                            </asp:DropDownList>
                                        </asp:Panel>
                                    </div>
                                </div>
                                <div class="wb-row">
                                    <div class="wb-label">
                                        Confirmed Status</div>
                                    <div class="wb-field">
                                        <asp:RadioButtonList ID="rdoConfirmStatus" runat="server" RepeatDirection="Horizontal" CssClass="wb-radio-list">
                                            <asp:ListItem Text="Both" Value="-1" Selected="True"></asp:ListItem>
                                            <asp:ListItem Text="Confirmed" Value="1"></asp:ListItem>
                                            <asp:ListItem Text="Pending" Value="0"></asp:ListItem>
                                        </asp:RadioButtonList>
                                    </div>
                                </div>
                                <div class="wb-actions">
                                    <asp:Button ID="btnViewFollowup" runat="server" Text="View" OnClick="btnViewFollowup_Click"
                                        CssClass="wb-btn" />
                                    <asp:Button ID="btnGenerateReport" runat="server" Text="Generate" OnClick="btnGenerateReport_Click"
                                        CssClass="wb-btn wb-btn-secondary" />
                                    <asp:Button ID="btnCancel" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Cancel" OnClick="btnCancel_Click" />
                                </div>
                            </div>
                        </div>
                    </asp:Panel>
                </div>
                <asp:Panel ID="pnlViewFollowup" runat="server">
                    <%-- Step UI2b (R12): the list keeps its frame and look; the frame is inside the panel, so no empty
                         frame shows before View --%>
                    <div class="formContent">
                        <div class="formPanel">
                            <div class="divRow">
                                    <asp:GridView ID="grvFollowup" runat="server" AutoGenerateColumns="false" CssClass="contentTable1"
                                        AllowSorting="true" CellPadding="4" DataKeyNames="MeetingId" Font-Names="Verdana, Arial, Helvetica, sans-serif"
                                        Font-Size="X-Small" ForeColor="#333333" GridLines="Horizontal" Height="32px"
                                        Width="100%" OnSorting="grvRecord_Sorting">
                                        <HeaderStyle CssClass="contentTableHeader" HorizontalAlign="Center" Font-Bold="true" />
                                        <Columns>
                                            <asp:TemplateField HeaderText="S.No.">
                                                <ItemTemplate>
                                                    <%# Container.DataItemIndex+1 + "."%>
                                                </ItemTemplate>
                                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Top" HorizontalAlign="Center"
                                                    Width="10px" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="CommitteeName">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="LinkButton1" runat="server" Text="Committee Name" CommandName="Sort"
                                                        Style="color: White" CommandArgument="CommitteeName"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblCommitteeName" SkinID="lblSkinGen" Text='<%# HttpUtility.HtmlEncode(Eval("CommitteeName")) %>' runat="server" />
                                                </ItemTemplate>
                                                <ItemStyle Width="100px" CssClass="contentTabletd" VerticalAlign="Top" HorizontalAlign="Left" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="MeetingNo">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="LinkButton7" runat="server" Text="Meeting No" CommandName="Sort"
                                                        Style="color: White" CommandArgument="MeetingNo"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblMeetingNoe" SkinID="lblSkinGen" Text='<%# HttpUtility.HtmlEncode(Eval("MeetingNo")) %>' runat="server" />
                                                    <asp:HiddenField ID="hdnMeetingNo" runat="server" />
                                                </ItemTemplate>
                                                <ItemStyle Width="70px" CssClass="contentTabletd" VerticalAlign="Top" HorizontalAlign="Center" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="MeetingDate">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="LinkButton2" runat="server" Text="Meeting Date" CommandName="Sort"
                                                        Style="color: White" CommandArgument="MeetingDate"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblMeetingDate" runat="server" SkinID="lblskingen" Text='<%#Eval("MeetingDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                                    <%--&nbsp; / &nbsp;
                                                    <asp:Label ID="lblMeetingTime" runat="server" SkinID="lblskingen" Text='<%#Eval("MeetingTime")%>'></asp:Label>
                                                    Hrs.--%>
                                                </ItemTemplate>
                                                <ItemStyle Width="90px" CssClass="contentTabletd" VerticalAlign="Top" HorizontalAlign="Center" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="AgendaNo">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="LinkButton3" runat="server" Text="Agenda No" CommandName="Sort"
                                                        Style="color: White" CommandArgument="AgendaNo"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblAgendaNo" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("AgendaNo")) %>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle Width="100px" CssClass="contentTabletd" VerticalAlign="Top" HorizontalAlign="Center" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="SubjectNo">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="LinkButton4" runat="server" Text="Sub.No." CommandName="Sort"
                                                        Style="color: White" CommandArgument="SubjectNo"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblSubjectNo" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("SubjectNo")) %>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle Width="50px" CssClass="contentTabletd" VerticalAlign="Top" HorizontalAlign="Center" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="DepartmentName">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="LinkButton5" runat="server" CommandArgument="DepartmentName"
                                                        CommandName="Sort" Style="color: White" Text="Dept. Name"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblDepartmentName" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("DepartmentName")) %>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle Width="100px" CssClass="contentTabletd" HorizontalAlign="Left" VerticalAlign="Top" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="ShortText">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="LinkButton6" runat="server" CommandArgument="ShortText" CommandName="Sort"
                                                        Style="color: White" Text="Agenda Short Text"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblShortText" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("ShortText")) %>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle CssClass="contentTabletd" HorizontalAlign="justify" VerticalAlign="Top" />
                                            </asp:TemplateField>
                                            <%-- Step FU2b: the Followup status of the item, as the Followup page shows it: the word and the line
                                                 of who confirmed or reopened it (Followup); the word Pending or Confirmed only (Followup
                                                 Summary). Headed "Followup status", as the printed Summary's column (and not to be taken for Minutes
                                                 status). Built and encoded in StatusCellHtml --%>
                                            <asp:TemplateField HeaderText="Followup status">
                                                <ItemTemplate>
                                                    <asp:Literal ID="litStatus" runat="server" Mode="PassThrough" Text='<%# StatusCellHtml(Container.DataItem) %>'></asp:Literal>
                                                </ItemTemplate>
                                                <ItemStyle Width="220px" CssClass="contentTabletd wb-followup-status-cell" HorizontalAlign="Left" VerticalAlign="Top" />
                                            </asp:TemplateField>
                                            <%-- Step RA1b: shown only in Management's Followup (the minutes status of the item) --%>
                                            <asp:TemplateField HeaderText="Minutes status" Visible="false">
                                                <ItemTemplate>
                                                    <asp:Label ID="lblMinutesStatus" runat="server" SkinID="lblskingen" Text='<%# StatusMarkText(Container.DataItem) %>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle Width="150px" CssClass="contentTabletd" HorizontalAlign="Left" VerticalAlign="Top" />
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
