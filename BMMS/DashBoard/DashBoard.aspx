<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="DashBoard.aspx.cs" Inherits="BMMS.DashBoard.DashBoard" Title="Untitled Page" %>

<%@ Register Src="../UserControl/MeetingSummary.ascx" TagName="MeetingSummary" TagPrefix="uc1" %>
<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <%-- Step UN6b: card layout. The MeetingSummary control renders the heading with the filters, the place of the
                 summary cards (UN6c) and the Meetings card; with the Alert and Action Item cards they are the cells of the
                 .wb-dash grid (Meetings about two thirds, Alerts one third, Action Items below; stacked under 1100 px). --%>
            <div class="wb-page wb-dash">
                <uc1:MeetingSummary ID="MeetingSummary1" runat="server"></uc1:MeetingSummary>
                <div class="wb-dash-msg" aria-live="polite">
                    <div id="divErrLogin" runat="server" class="divErrorHide">
                        <span id="spanErrLogin" runat="server" class="lblError"></span>
                    </div>
                </div>
                <div class="wb-card wb-dash-alerts">
                    <div class="wb-card-header wb-dash-card-header">
                        <h2 class="wb-dash-card-title">Alerts</h2>
                        <div class="wb-dash-links">
                            <%-- Step UN6c1: Recent (the default: every unread alert and the read ones of the last 7 days),
                                 Unread, All (everything that was not removed from the list; nothing is deleted) --%>
                            <asp:LinkButton runat="server" ID="lnkRecent" OnClick="AlertMode_Click" CommandArgument="R"
                                ToolTip="Unread alerts, and read alerts of the last 7 days">Recent</asp:LinkButton>
                            |
                            <asp:LinkButton runat="server" ID="lnkUnread" OnClick="AlertMode_Click" CommandArgument="U"
                                ToolTip="Unread alerts only">Unread</asp:LinkButton>
                            |
                            <asp:LinkButton runat="server" ID="lnkAll" OnClick="AlertMode_Click" CommandArgument="A"
                                ToolTip="All alerts, also older ones you have read">All</asp:LinkButton>
                        </div>
                    </div>
                    <div class="wb-card-body">
                        <asp:HiddenField ID="hdnAlertUserId" runat="server" />
                        <asp:Button ID="btnShowPopup" runat="server" Style="display: none" />
                        <div aria-live="polite">
                            <p id="pAlertsMessage" runat="server" class="wb-dash-message" visible="false"></p>
                        </div>
                        <div class="wb-table-scroll">
                            <%-- Step UN6c1: a page of 10 comes from the server (spr_GetDashboardAlerts, step 43); the list
                                 is not kept in ViewState --%>
                            <asp:GridView ID="grvAlert" runat="server" Width="100%" CellPadding="4" CssClass="contentTable1"
                                AutoGenerateColumns="false" OnRowDataBound="grvAlert_RowDataBound" AllowPaging="True"
                                AllowCustomPaging="True" OnPageIndexChanging="OnPaging" PageSize="10">
                                <Columns>
                                    <%-- Step UN6b (Finding B): two columns in the narrow card. The first holds the Source
                                         link, the hidden values that lnkSource_Click reads, and one muted line with the
                                         alert type, committee and department; the second the date (dd-MMM-yyyy, the time
                                         below it, neither wraps).
                                         Step UN6c1: the muted line ends with the person who caused the alert (entered,
                                         approved, rejected, edited; the login ID as tooltip, as in the header; a dash when
                                         nobody is recorded), and the date is that of this event. --%>
                                    <asp:TemplateField HeaderText="Alert">
                                        <ItemTemplate>
                                            <div class="wb-dash-alert">
                                                <asp:LinkButton ID="lnkSource" runat="server" CssClass="wb-dash-alert-source" Text='<%# HttpUtility.HtmlEncode(Eval("DisplayText")) %>' OnClick="lnkSource_Click">
                                                </asp:LinkButton>
                                                <span class="wb-dash-alert-meta"><%# HttpUtility.HtmlEncode(AlertDetails(Eval("AlertTypeName"), Eval("CommitteeName"), Eval("DepartmentName"))) %> | by <span class="wb-dash-alert-actor" title='<%# HttpUtility.HtmlAttributeEncode(ActorLogin(Eval("ActorLogin"))) %>'><%# HttpUtility.HtmlEncode(ActorName(Eval("ActorName"))) %></span></span>
                                            </div>
                                            <asp:Label ID="lblSourceType" runat="server" Text='<%#Bind("SourceType") %>' Visible="false"></asp:Label>
                                            <asp:Label ID="lblSourceTypeId" runat="server" Text='<%#Bind("SourceTypeId") %>'
                                                Visible="false"></asp:Label>
                                            <asp:Label ID="lblAlertUserId" runat="server" Text='<%#Bind("AlertUserId") %>' Visible="false"></asp:Label>
                                            <asp:Label ID="lblAlert" runat="server" Text='<%#Bind("AlertId") %>' Visible="false"></asp:Label>
                                        </ItemTemplate>
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Date">
                                        <ItemTemplate>
                                            <span class="wb-dash-date"><%# HttpUtility.HtmlEncode(FormatDate(Eval("EventOn"))) %></span>
                                            <span class="wb-dash-time"><%# HttpUtility.HtmlEncode(FormatTimeOfDay(Eval("EventOn"))) %></span>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="wb-dash-alert-when" />
                                        <HeaderStyle CssClass="wb-dash-alert-when" />
                                    </asp:TemplateField>
                                </Columns>
                                <EmptyDataTemplate>
                                    <div class="divNoRecord">No alerts.</div>
                                </EmptyDataTemplate>
                                <HeaderStyle HorizontalAlign="Center" Font-Bold="True" CssClass="contentTableHeader" />
                                <RowStyle CssClass="contentTabletd" Height="20px" />
                                <PagerSettings Mode="NumericFirstLast" PageButtonCount="5" />
                            </asp:GridView>
                        </div>
                    </div>
                </div>
                <%-- Step UN6c1: the card is hidden when the server answers that the role has no Action Items card
                     (MD Secretariat, Admin; Reason 4 of spr_GetDashboardActionItems) --%>
                <div id="cardActionItems" runat="server" class="wb-card wb-dash-actions">
                    <div class="wb-card-header wb-dash-card-header">
                        <h2 class="wb-dash-card-title">Action Items</h2>
                        <div class="wb-dash-links">
                            <asp:LinkButton runat="server" ID="lnkActShowall" OnClick="lnkActShowall_Click">Show All</asp:LinkButton>
                            |
                            <asp:LinkButton runat="server" ID="lnkActRead" OnClick="lnkActRead_Click">Read</asp:LinkButton>
                            |
                            <asp:LinkButton runat="server" ID="lnkActUnRead" OnClick="lnkActUnRead_Click">Unread</asp:LinkButton>
                        </div>
                    </div>
                    <div class="wb-card-body">
                        <div aria-live="polite">
                            <p id="pActionItemsMessage" runat="server" class="wb-dash-message" visible="false"></p>
                        </div>
                        <div class="wb-table-scroll">
                            <asp:GridView ID="grvActionItem" runat="server" Width="100%" CellPadding="4" CssClass="contentTable1"
                                AutoGenerateColumns="false" OnRowDataBound="grvActionItem_RowDataBound" OnPageIndexChanging="OnPagingAction"
                                AllowPaging="True" PageSize="10">
                                <Columns>
                                    <asp:TemplateField HeaderText="Committee">
                                        <ItemTemplate>
                                            <asp:LinkButton ID="lnkActionItem" runat="server" Text='<%# HttpUtility.HtmlEncode(Eval("CommitteeName")) %>'
                                                OnClick="lnkActionItem_Click">
                                            </asp:LinkButton>
                                            <asp:Label ID="lblActionItemId" runat="server" Text='<%#Bind("ActionItemId") %>'
                                                Visible="false"></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle VerticalAlign="Middle" HorizontalAlign="Left" />
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Agenda No" Visible="true">
                                        <ItemTemplate>
                                            <asp:Label ID="lblAgendaNo" runat="server" Text='<%# HttpUtility.HtmlEncode(Eval("AgendaNo")) %>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Subject No" Visible="true">
                                        <ItemTemplate>
                                            <asp:Label ID="lblSubjectNo" runat="server" Text='<%# HttpUtility.HtmlEncode(Eval("SubjectNo")) %>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Meeting Date" Visible="true">
                                        <ItemTemplate>
                                            <asp:Label ID="lblMeetingDate" runat="server" CssClass="wb-dash-date" Text='<%# HttpUtility.HtmlEncode(FormatDate(Eval("MeetingDate"))) %>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle Width="100px" Height="35px" VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Decision Type" Visible="true">
                                        <ItemTemplate>
                                            <asp:Label ID="lblDecisionTypeName" runat="server" Text='<%# HttpUtility.HtmlEncode(Eval("DecisionTypeName")) %>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    <%-- Step UN6c1: the due date of a Followup (optional, step UN6a) and the word "Overdue" when
                                         it has passed and the item is neither complied nor confirmed (IsOverdue of
                                         spr_GetDashboardActionItems, by the database server's date). No due date: empty. --%>
                                    <asp:TemplateField HeaderText="Due date">
                                        <ItemTemplate>
                                            <span class="wb-dash-date"><%# HttpUtility.HtmlEncode(FormatDate(Eval("DueDate"))) %></span>
                                            <asp:PlaceHolder ID="phOverdue" runat="server" Visible='<%# IsOverdue(Eval("IsOverdue")) %>'><span class="wb-chip wb-chip-red wb-dash-overdue">Overdue</span></asp:PlaceHolder>
                                        </ItemTemplate>
                                        <ItemStyle VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Read" Visible="False">
                                        <ItemTemplate>
                                            <asp:Label ID="lblReadStatus" runat="server" Text='<%#Eval("ReadStatus") %>'></asp:Label>
                                        </ItemTemplate>
                                    </asp:TemplateField>
                                </Columns>
                                <EmptyDataTemplate>
                                    <div class="divNoRecord">
                                        <%#Session["NoRecord"].ToString()%>
                                    </div>
                                </EmptyDataTemplate>
                                <HeaderStyle HorizontalAlign="Center" Font-Bold="True" CssClass="contentTableHeader" />
                                <RowStyle CssClass="contentTabletd" Height="20px" />
                                <PagerSettings Mode="NumericFirstLast" PageButtonCount="5" />
                            </asp:GridView>
                        </div>
                    </div>
                </div>
            </div>
            <cc1:ModalPopupExtender ID="MpCommittee" TargetControlID="btnShowPopup" runat="server"
                PopupControlID="pnlAlert" BackgroundCssClass="modalBackground">
            </cc1:ModalPopupExtender>
            <%-- Step UN6b: was Width="610px"; at most 610 px, never wider than the window --%>
            <asp:Panel ID="pnlAlert" runat="server" CssClass="wb-dash-popup" Style="height: 500px;">
                <div style="float: left; width: 100%; background-color: White; padding-top: 10px;">
                    <asp:Panel ID="pnlCommittee" runat="server">
                        <div class="formContent">
                            <div class="formPanel">
                                <div class="divHeader">
                                    :: Committee Alert</div>
                                <div class="divRow">
                                    <div class="divRow">
                                        <div class="divRow">
                                            <div class="divRowLeft">
                                                Committee Code :
                                            </div>
                                            <div class="divRowRight">
                                                <asp:TextBox ID="txtCommitteeCode" runat="server" ReadOnly="true"></asp:TextBox>
                                                <asp:HiddenField ID="hdnCommitteeId" runat="server" />
                                            </div>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRow">
                                            <div class="divRowLeft">
                                                Committee Name :
                                            </div>
                                            <div class="divRowRight">
                                                <asp:TextBox ID="txtCommitteeName" runat="server" ReadOnly="true"></asp:TextBox>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRow">
                                            <div class="divRowLeft">
                                                Incorporation Date :
                                            </div>
                                            <div class="divRowRight">
                                                <asp:TextBox ID="txtIncorporationDate" runat="server" ReadOnly="true"></asp:TextBox>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </asp:Panel>
                    <asp:Panel ID="pnlMeeting" runat="server">
                        <div class="formContent">
                            <div class="formPanel">
                                <div class="divHeader">
                                    :: Meeting Alert</div>
                                <div class="divRow">
                                    <div class="divRow">
                                        <div class="divRow">
                                            <div class="divRowLeft">
                                                Meeting No :
                                            </div>
                                            <div class="divRowRight">
                                                <asp:TextBox ID="txtMeetingNo" runat="server" MaxLength="6" ReadOnly="true"></asp:TextBox>
                                                <asp:HiddenField ID="hdnMeetingId" runat="server" />
                                            </div>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRow">
                                            <div class="divRowLeft">
                                                Committee Name :
                                            </div>
                                            <div class="divRowRight">
                                                <asp:TextBox ID="txtCommittee" runat="server" ReadOnly="true"></asp:TextBox>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRow">
                                            <div class="divRowLeft">
                                                Venue :
                                            </div>
                                            <div class="divRowRight">
                                                <asp:TextBox ID="txtVenue" runat="server" TextMode="MultiLine" Height="50px" ReadOnly="true"></asp:TextBox>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRow">
                                            <div class="divRowLeft">
                                                Meeting Date :
                                            </div>
                                            <div class="divRowRight">
                                                <asp:TextBox ID="txtMeetingDate" runat="server" ReadOnly="true"></asp:TextBox>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRow">
                                            <div class="divRowLeft">
                                                Meeting Time :
                                            </div>
                                            <div class="divRowRight">
                                                <asp:TextBox ID="txtMeetingTime" CssClass="txtTimeFormat" runat="server" ReadOnly="true"></asp:TextBox>
                                                Hrs.
                                            </div>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRow">
                                            <div class="divRowLeft">
                                                Agenda Submission Date :
                                            </div>
                                            <div class="divRowRight">
                                                <asp:TextBox ID="txtAgendaSubmissionDate" runat="server" ReadOnly="true"></asp:TextBox>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </asp:Panel>
                    <div style="float: left; width: 100%; height: 40px; text-align: center;">
                        <asp:Button ID="btnClose" runat="server" Text="Close" CssClass="button" Width="50px"
                            OnClick="btnClose_Click" />
                        <asp:Button ID="btnDeleteAlert" runat="server" Text="Remove from my list" CssClass="button" OnClick="btnDeleteAlert_Click" />
                    </div>
                </div>
            </asp:Panel>
            <asp:Panel ID="pnlCommitteeDtl" runat="server" Style="display: none;">
                <%--    <asp:UpdatePanel runat="server" id="UpCommittee"  UpdateMode="Conditional">
            <contenttemplate></contenttemplate>

                                        </asp:UpdatePanel>--%>
                <asp:DataGrid CellPadding="0" CellSpacing="0" GridLines="Both" runat="server" ID="grdCommiteeDtl"
                    Width="100%" CssClass="contentTable1" AutoGenerateColumns="false" AllowPaging="True"
                    PageSize="10">
                    <HeaderStyle HorizontalAlign="Center" Font-Bold="True" CssClass="contentTableHeader" />
                    <ItemStyle CssClass="contentTabletd" Height="20px" />
                    <Columns>
                        <asp:BoundColumn DataField="committee_id" Visible="False" HeaderText="CommiteeId">
                            <ItemStyle HorizontalAlign="Center" />
                        </asp:BoundColumn>
                        <asp:BoundColumn DataField="committee_code" HeaderText="Committee Code">
                            <ItemStyle HorizontalAlign="Center" />
                        </asp:BoundColumn>
                        <asp:BoundColumn DataField="committee_name" HeaderText="Committee Name">
                            <ItemStyle HorizontalAlign="Left" />
                        </asp:BoundColumn>
                        <asp:BoundColumn DataField="incorporation_date" HeaderText="Date Of Incorporation"></asp:BoundColumn>
                        <asp:BoundColumn DataField="cessation_date" HeaderText="Date of Cessation">
                            <ItemStyle HorizontalAlign="Center" />
                        </asp:BoundColumn>
                        <asp:BoundColumn DataField="Status" HeaderText="Status">
                            <ItemStyle HorizontalAlign="Center" />
                        </asp:BoundColumn>
                    </Columns>
                    <PagerStyle Mode="NumericPages" />
                </asp:DataGrid>
                <div style="text-align: right; width: 100%; margin-top: 5px;">
                    <asp:Button ID="btnClose1" runat="server" Text="Close" Width="50px" />
                </div>
            </asp:Panel>
            <asp:Panel ID="pnlAgenda" runat="server" Style="background-color: White;">
                <div class="MyPopupOuter">
                    <div class="MyPopupContent">
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
                        <div class="formContent wb-dash-pane">
                            <div class="formPanel">
                                <div class="divHeader">
                                    <div style="float: left;">
                                        :: Agenda Alert
                                    </div>
                                    <div style="float: right;">
                                        <asp:Button ID="Button1" runat="server" Text="X" ToolTip="Close" CssClass="button"
                                            OnClick="btnAgendaClose_Click" />
                                    </div>
                                </div>
                                <div class="divRow">
                                    <div class="divRow">
                                        <div class="divRowLeft">
                                            <div class="divRowLeft">
                                                Agenda No :
                                            </div>
                                            <div class="divRowRight">
                                                <asp:TextBox ID="txtAgendaNo" runat="server" ReadOnly="true" Width="200px"></asp:TextBox>
                                                <asp:HiddenField ID="hdnAgendaId" runat="server" />
                                            </div>
                                        </div>
                                        <div class="divRowRight">
                                            <div class="divRowLeft" style="width: 140px">
                                                Subject No :
                                            </div>
                                            <div class="divRowRight">
                                                <asp:TextBox ID="txtSubjectNo" runat="server" ReadOnly="true" Width="200px"></asp:TextBox>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRowLeft">
                                            <div class="divRowLeft">
                                                Committee Name :
                                            </div>
                                            <div class="divRowRight">
                                                <asp:TextBox ID="txtAgendaCommittee" runat="server" ReadOnly="true" Width="200px"></asp:TextBox>
                                                <asp:HiddenField ID="hdnAgendaCommittee" runat="server" />
                                            </div>
                                        </div>
                                        <div class="divRowRight">
                                            <div class="divRowLeft" style="width: 140px">
                                                Meeting No :
                                            </div>
                                            <div class="divRowRight">
                                                <asp:TextBox ID="txtAgendaMeeting" runat="server" ReadOnly="true" Width="200px"></asp:TextBox>
                                                <asp:HiddenField ID="hdnAgendaMeeting" runat="server" />
                                            </div>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRowLeft">
                                            <div class="divRowLeft">
                                                Meeting Date :
                                            </div>
                                            <div class="divRowRight">
                                                <asp:TextBox ID="txtDateOfMeeting" runat="server" ReadOnly="true" Width="200px"></asp:TextBox>
                                            </div>
                                        </div>
                                        <div class="divRowRight">
                                            <div class="divRowLeft" style="width: 140px">
                                                Department :
                                            </div>
                                            <div class="divRowRight">
                                                <asp:TextBox ID="txtAgendaDepartment" runat="server" ReadOnly="true" Width="200px"></asp:TextBox>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRowLeft">
                                            <div class="divRowLeft">
                                                Subject Type :
                                            </div>
                                            <div class="divRowRight">
                                                <asp:TextBox ID="txtSubjectType" runat="server" ReadOnly="true"></asp:TextBox>
                                            </div>
                                        </div>
                                        <div class="divRowRight">
                                            <div class="divRowLeft">
                                            </div>
                                            <div class="divRowRight">
                                            </div>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRowLeft wb-dash-plabel">
                                            Short Text :
                                        </div>
                                        <div class="divRowRight wb-dash-pfield">
                                            <asp:TextBox ID="txtShortText" runat="server" ReadOnly="true" TextMode="MultiLine"
                                                Height="100px" Width="100%"></asp:TextBox>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRowLeft wb-dash-plabel">
                                            Agenda Text :
                                        </div>
                                        <div class="divRowRight wb-dash-pfield">
                                            <bmms:RichTextEditor ID="ftxtAgendaText" runat="server" Width="100%" Height="100px" ReadOnly="true" Label="Agenda Text" />
                                            <a id="aAgendaText" runat="server" target="_blank">View</a>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRowLeft wb-dash-plabel">
                                            Proposed Resolution :
                                        </div>
                                        <div class="divRowRight wb-dash-pfield">
                                            <%--<asp:TextBox ID="txtProposedResolution" runat="server" ReadOnly="true" TextMode="MultiLine"
                                            Height="100px" Width="100%"></asp:TextBox>--%>
                                            <bmms:RichTextEditor ID="ftxtProposedResolution" runat="server" Width="100%" Height="100px" Label="Proposed Resolution" />
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRowLeft wb-dash-plabel">
                                            Files to be Attached :
                                        </div>
                                        <div class="divRowRight wb-dash-pfield">
                                            <asp:GridView ID="grvAttachedFiles" runat="server" AutoGenerateColumns="False" ShowHeader="False"
                                                CssClass="contentTable1" BorderStyle="None" BorderWidth="1px"
                                                CellPadding="3" CellSpacing="2">
                                                <Columns>
                                                    <asp:TemplateField SortExpression="FilePath">
                                                        <ItemTemplate>
                                                            <a href='<%# HttpUtility.HtmlEncode(Eval("FilePath")) %>' target="_blank">
                                                                <%# HttpUtility.HtmlEncode(Eval("DisplayName")) %>
                                                            </a>
                                                        </ItemTemplate>
                                                    </asp:TemplateField>
                                                </Columns>
                                                <RowStyle CssClass="contentTabletd" />
                                                <FooterStyle CssClass="contentTabletd" />
                                                <PagerStyle HorizontalAlign="Center" />
                                                <SelectedRowStyle CssClass="bmms-row-selected" Font-Bold="True" />
                                                <HeaderStyle CssClass="contentTableHeader" Font-Bold="True" />
                                            </asp:GridView>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <%-- Step UN4: who wrote the comment and when, on its own line under the label (set and encoded in the code) --%>
                                        <div class="divRowLeft wb-dash-plabel">
                                            Manager's comment :
                                            <asp:Label ID="lblManagerCommentBy" runat="server" CssClass="bmms-comment-by bmms-comment-by-line" />
                                        </div>
                                        <div class="divRowRight wb-dash-pfield">
                                            <bmms:RichTextEditor ID="ftxtManagerComments" runat="server" Width="100%" Height="100px" Label="Manager's comment" />
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRowLeft wb-dash-plabel">
                                            Controller's comment :
                                            <asp:Label ID="lblControllerCommentBy" runat="server" CssClass="bmms-comment-by bmms-comment-by-line" />
                                        </div>
                                        <div class="divRowRight wb-dash-pfield">
                                            <bmms:RichTextEditor ID="ftxtControllerComments" runat="server" Width="100%" Height="100px" Label="Controller's comment" />
                                        </div>
                                    </div>
                                </div>
                                <div class="divRow">
                                    <div class="divRow">
                                        <div class="divRowLeft">
                                            <span class="spanWhite">.</span>
                                        </div>
                                        <div class="divRowRight">
                                            <asp:Panel ID="pnlAgendaControls" runat="server">
                                                <asp:Button ID="btnApprove" runat="server" Text="Approve" CssClass="button" OnClick="btnApprove_Click" />
                                                <asp:Button ID="btnReject" runat="server" Text="Reject" CssClass="button" OnClick="btnReject_Click" />
                                                <asp:Button ID="btnAgendaClose" runat="server" Text="Close" CssClass="button" OnClick="btnAgendaClose_Click" />
                                                <asp:Button ID="btnDeleteAgendaAlert" runat="server" CssClass="button" OnClick="btnDeleteAlert_Click"
                                                    Text="Remove from my list" />
                                            </asp:Panel>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </asp:Panel>
            <asp:Panel ID="pnlActionItemDetails" runat="server" Style="background-color: White;">
                <div class="MyPopupOuter">
                    <div class="MyPopupContent">
                        <div class="formContent wb-dash-pane">
                            <div class="formPanel">
                                <div class="divHeader">
                                    <div style="float: left;">
                                        :: Action Item Details
                                    </div>
                                    <div style="float: right;">
                                        <asp:Button ID="Button2" runat="server" Text="X" ToolTip="Close" CssClass="button"
                                            OnClick="btnActionItemClose_Click" />
                                    </div>
                                </div>
                                <div class="divRow">
                                    <div class="divRow">
                                        <div class="divRowLeft">
                                            <div class="divRowLeft">
                                                Agenda Number :
                                            </div>
                                            <div class="divRowRight">
                                                <asp:TextBox ID="txtAgendaNumber" runat="server" ReadOnly="true" Width="200px"></asp:TextBox>
                                                <asp:HiddenField ID="hdnActionItemId" runat="server" />
                                            </div>
                                        </div>
                                        <div class="divRowRight">
                                            <div class="divRowLeft">
                                                Subject Number :
                                            </div>
                                            <div class="divRowRight">
                                                <asp:TextBox ID="txtSubjectNumber" runat="server" ReadOnly="true" Width="200px"></asp:TextBox>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRowLeft">
                                            <div class="divRowLeft">
                                                Department :
                                            </div>
                                            <div class="divRowRight">
                                                <asp:TextBox ID="txtActionDepartment" runat="server" ReadOnly="true" Width="200px"></asp:TextBox>
                                            </div>
                                        </div>
                                        <div class="divRowRight">
                                            <div class="divRowLeft">
                                                Decision Type :
                                            </div>
                                            <div class="divRowRight">
                                                <asp:TextBox ID="txtDecisionType" runat="server" ReadOnly="true" Width="200px"></asp:TextBox>
                                                <asp:HiddenField ID="HiddenField3" runat="server" />
                                            </div>
                                        </div>
                                    </div>
                                    <%--<div class="divRow">
                                    <div class="divRowLeft">
                                        <div class="divRowLeft">
                                            Due Date :
                                        </div>
                                        <div class="divRowRight">
                                            <asp:TextBox ID="txtDueDate" runat="server" ReadOnly="true" Width="200px"></asp:TextBox>
                                        </div>
                                    </div>
                                    <div class="divRowRight">
                                        <div class="divRowLeft" style="width: 140px">
                                        </div>
                                        <div class="divRowRight">
                                        </div>
                                    </div>
                                </div>--%>
                                    <div class="divRow">
                                        <div class="divRowLeft wb-dash-plabel">
                                            Actual Resolution :
                                        </div>
                                        <div class="divRowRight wb-dash-pfield">
                                            <bmms:RichTextEditor ID="ftxtActualResolution" runat="server" Width="100%" Height="100px" ReadOnly="true" Label="Actual Resolution" />
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRowLeft wb-dash-plabel">
                                            Action Text :
                                        </div>
                                        <div class="divRowRight wb-dash-pfield">
                                            <bmms:RichTextEditor ID="ftxtActionText" runat="server" Width="100%" Height="100px" ReadOnly="true" Label="Action Text" />
                                        </div>
                                    </div>
                                </div>
                                <div class="divRow">
                                    <div class="divRow">
                                        <div class="divRowLeft">
                                            <span class="spanWhite">.</span>
                                        </div>
                                        <div class="divRowRight">
                                            <asp:Panel ID="Panel2" runat="server">
                                                <asp:Button ID="btnActionItemApprove" runat="server" Text="Submit" CssClass="button"
                                                    OnClick="btnActionItemApprove_Click" />
                                                <asp:Button ID="btnActionItemClose" runat="server" Text="Close" CssClass="button"
                                                    OnClick="btnActionItemClose_Click" />
                                                <asp:Button ID="btnActionItemCancel" runat="server" Text="Cancel" CssClass="button"
                                                    OnClick="btnActionItemCancel_Click" />
                                            </asp:Panel>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </asp:Panel>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
