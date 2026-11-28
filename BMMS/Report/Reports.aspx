<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="Reports.aspx.cs" Inherits="BMMS.Report.Reports" Title="Untitled Page" %>

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
                <%-- Step UI2b: the Masters' form look (Committee Master): breadcrumb and title as in the menu (the text of
                     lblPageHeader, set from the query string in Page_Load), a card with label and field rows, View as the
                     primary button and Generate as the secondary one, in today's order (D8). The grid stays outside
                     .wb-page in its old frame (R12). Control IDs, events and the handlers are unchanged. --%>
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
                    <asp:Panel ID="pnlReportFilter" runat="server">
                        <div class="wb-card">
                            <div class="wb-card-header">
                                Filter</div>
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
                                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlDepartment">
                                        Department</label>
                                    <div class="wb-field">
                                        <asp:DropDownList ID="ddlDepartment" runat="server" AutoPostBack="true"
                                            OnSelectedIndexChanged="ddlDepartment_SelectedIndexChanged">
                                        </asp:DropDownList>
                                    </div>
                                </div>
                                <div class="wb-row">
                                    <div class="wb-label">
                                        Meeting No.</div>
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
                                    </div>
                                    <div class="wb-field">
                                        <asp:Panel ID="pnlMeetingNoParticular" runat="server">
                                            <asp:DropDownList ID="ddlMeetingNo" runat="server" CssClass="wb-filter-select wb-filter-meetno" AutoPostBack="true"
                                                OnSelectedIndexChanged="ddlMeetingNo_SelectedIndexChanged">
                                            </asp:DropDownList>
                                        </asp:Panel>
                                        <asp:Panel ID="pnlMeetingNoBetween" runat="server">
                                            <asp:DropDownList ID="ddlMeetingNoFrom" runat="server" CssClass="wb-filter-select wb-filter-meetno">
                                            </asp:DropDownList>
                                            <asp:Label ID="Label1" runat="server" CssClass="wb-unit" Text=" to "></asp:Label>
                                            <asp:DropDownList ID="ddlMeetingNoTo" runat="server" CssClass="wb-filter-select wb-filter-meetno">
                                            </asp:DropDownList>
                                        </asp:Panel>
                                    </div>
                                </div>
                                <div class="wb-row">
                                    <div class="wb-label">
                                        Subject No.</div>
                                    <div class="wb-field">
                                        <asp:RadioButtonList ID="rdoSubjectNoSearch" runat="server" RepeatDirection="Horizontal"
                                            CssClass="wb-radio-list" AutoPostBack="true" OnSelectedIndexChanged="rdoSubjectNoSearch_SelectedIndexChanged">
                                            <asp:ListItem Text="All" Value="0" Selected="True"></asp:ListItem>
                                            <asp:ListItem Text="Between" Value="1"></asp:ListItem>
                                        </asp:RadioButtonList>
                                    </div>
                                </div>
                                <div class="wb-row">
                                    <div class="wb-label">
                                    </div>
                                    <div class="wb-field">
                                        <asp:DropDownList ID="ddlSubjectNoFrom" runat="server" CssClass="wb-filter-select wb-filter-short">
                                        </asp:DropDownList>
                                        <span class="wb-unit">To</span>
                                        <asp:DropDownList ID="ddlSubjectNoTo" runat="server" CssClass="wb-filter-select wb-filter-short">
                                        </asp:DropDownList>
                                    </div>
                                </div>
                                <div class="wb-actions">
                                    <asp:Button ID="btnView" runat="server" Text="View" OnClick="btnView_Click" CssClass="wb-btn" />
                                    <asp:Button ID="btnGenerateReport" runat="server" Text="Generate" OnClick="btnGenerateReport_Click"
                                        CssClass="wb-btn wb-btn-secondary" />
                                </div>
                            </div>
                        </div>
                    </asp:Panel>
                </div>
                <asp:Panel ID="pnlViewReport" runat="server">
                    <%-- Step UI2b (R12): the grid keeps its frame and look; the frame is inside the panel, so no empty
                         frame shows before View --%>
                    <div class="formContent">
                        <div class="formPanel">
                            <div class="divRow">
                                <asp:GridView ID="grvMinutes" runat="server" AutoGenerateColumns="false" CssClass="contentTable1"
                                    AllowSorting="true" CellPadding="4" DataKeyNames="MeetingId" Font-Names="Verdana, Arial, Helvetica, sans-serif"
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
                                        <asp:TemplateField SortExpression="MeetingNo">
                                            <HeaderTemplate>
                                                <asp:LinkButton ID="LinkButton1" runat="server" Text="Meeting No" CommandName="Sort"
                                                    Style="color: White" CommandArgument="MeetingNo"></asp:LinkButton>
                                            </HeaderTemplate>
                                            <ItemTemplate>
                                                <asp:Label ID="lblMeetingNoe" SkinID="lblSkinGen" Text='<%#Eval("MeetingNo")%>' runat="server" />
                                                <asp:HiddenField ID="hdnMeetingNo" runat="server" />
                                            </ItemTemplate>
                                            <ItemStyle Width="70px" CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
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
                                            <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                        </asp:TemplateField>
                                        <asp:TemplateField SortExpression="AgendaNo">
                                            <HeaderTemplate>
                                                <asp:LinkButton ID="LinkButton3" runat="server" Text="Agenda No" CommandName="Sort"
                                                    Style="color: White" CommandArgument="AgendaNo"></asp:LinkButton>
                                            </HeaderTemplate>
                                            <ItemTemplate>
                                                <asp:Label ID="lblAgendaNo" runat="server" SkinID="lblskingen" Text='<%#Eval("AgendaNo")%>'></asp:Label>
                                            </ItemTemplate>
                                            <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                        </asp:TemplateField>
                                        <asp:TemplateField SortExpression="SubjectNo">
                                            <HeaderTemplate>
                                                <asp:LinkButton ID="LinkButton4" runat="server" Text="Sub.No." CommandName="Sort"
                                                    Style="color: White" CommandArgument="SubjectNo"></asp:LinkButton>
                                            </HeaderTemplate>
                                            <ItemTemplate>
                                                <asp:Label ID="lblSubjectNo" runat="server" SkinID="lblskingen" Text='<%#Eval("SubjectNo")%>'></asp:Label>
                                            </ItemTemplate>
                                            <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                        </asp:TemplateField>
                                        <asp:TemplateField SortExpression="DepartmentName">
                                            <HeaderTemplate>
                                                <asp:LinkButton ID="LinkButton5" runat="server" CommandArgument="DepartmentName"
                                                    CommandName="Sort" Style="color: White" Text="Department Name"></asp:LinkButton>
                                            </HeaderTemplate>
                                            <ItemTemplate>
                                                <asp:Label ID="lblDepartmentName" runat="server" SkinID="lblskingen" Text='<%#Eval("DepartmentName")%>'></asp:Label>
                                            </ItemTemplate>
                                            <ItemStyle CssClass="contentTabletd" HorizontalAlign="Left" VerticalAlign="Middle" />
                                        </asp:TemplateField>
                                        <asp:TemplateField SortExpression="ShortText">
                                            <HeaderTemplate>
                                                <asp:LinkButton ID="LinkButton6" runat="server" CommandArgument="ShortText" CommandName="Sort"
                                                    Style="color: White" Text="Agenda Short Text"></asp:LinkButton>
                                            </HeaderTemplate>
                                            <ItemTemplate>
                                                <asp:Label ID="lblShortText" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("ShortText")) %>'></asp:Label>
                                            </ItemTemplate>
                                            <ItemStyle Width="450px" CssClass="contentTabletd" HorizontalAlign="Left" VerticalAlign="Middle" />
                                        </asp:TemplateField>
                                        <%-- Step RA1b: shown only in the every-status Minutes report (Controller, Management) --%>
                                        <asp:TemplateField HeaderText="Minutes status" Visible="false">
                                            <ItemTemplate>
                                                <asp:Label ID="lblMinutesStatus" runat="server" SkinID="lblskingen" Text='<%# StatusMarkText(Container.DataItem) %>'></asp:Label>
                                            </ItemTemplate>
                                            <ItemStyle Width="150px" CssClass="contentTabletd" HorizontalAlign="Left" VerticalAlign="Middle" />
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
