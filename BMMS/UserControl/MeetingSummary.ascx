<%@ Control Language="C#" AutoEventWireup="true" Codebehind="MeetingSummary.ascx.cs"
    Inherits="BMMS.UserControl.MeetingSummary" %>
<%-- Step UN6b: the Dashboard heading with the filters, the place of the summary cards (UN6c) and the Meetings card.
     The control renders no wrapper of its own: its three blocks are cells of the Dashboard grid (.wb-dash). --%>
<div class="wb-dash-head">
    <div class="wb-dash-title">
        <h1 class="wb-h1">Dashboard</h1>
        <p id="pSubtitle" runat="server" class="wb-dash-subtitle" visible="false"></p>
    </div>
    <%-- Hidden until a load succeeds: the code shows only the filters of the role (a failed load shows none) --%>
    <div id="divFilters" runat="server" class="wb-dash-filters" visible="false">
        <div id="divDepartmentFilter" runat="server" class="wb-dash-filter" visible="false">
            <asp:Label ID="lblDepartment" runat="server" AssociatedControlID="ddlDepartment" Text="Department" />
            <asp:DropDownList ID="ddlDepartment" runat="server" AutoPostBack="true" OnSelectedIndexChanged="Filter_Changed" />
        </div>
        <div id="divCommitteeFilter" runat="server" class="wb-dash-filter" visible="false">
            <asp:Label ID="lblCommittee" runat="server" AssociatedControlID="ddlCommittee" Text="Committee" />
            <asp:DropDownList ID="ddlCommittee" runat="server" AutoPostBack="true" OnSelectedIndexChanged="Filter_Changed" />
        </div>
    </div>
</div>
<%-- Summary cards: step UN6c. Empty until then; it takes no space while empty. --%>
<div class="wb-dash-summary" id="divSummaryCards"></div>
<div class="wb-card wb-dash-meetings">
    <div class="wb-card-header">
        <h2 class="wb-dash-card-title"><asp:Literal ID="litMeetingsTitle" runat="server" Mode="Encode" Text="Meetings" /></h2>
    </div>
    <div class="wb-card-body">
        <div aria-live="polite">
            <p id="pMeetingsMessage" runat="server" class="wb-dash-message" visible="false"></p>
        </div>
        <asp:Panel ID="pnlMeetingLists" runat="server">
            <h3 class="wb-section-title">Scheduled</h3>
            <div class="wb-table-scroll">
                <asp:GridView ID="grvScheduled" runat="server" CssClass="wb-table wb-dash-table" AutoGenerateColumns="False"
                    GridLines="None" UseAccessibleHeader="true" EmptyDataText="No scheduled meetings.">
                    <Columns>
                        <asp:TemplateField HeaderText="Meeting">
                            <ItemTemplate>
                                <span class="wb-dash-committee"><%# HttpUtility.HtmlEncode(Eval("CommitteeName")) %></span>
                                <span class="wb-dash-meeting-no">No <%# HttpUtility.HtmlEncode(Eval("MeetingNo")) %></span>
                            </ItemTemplate>
                        </asp:TemplateField>
                        <asp:TemplateField HeaderText="Meeting date">
                            <ItemTemplate>
                                <span class="wb-dash-date"><%# HttpUtility.HtmlEncode(FormatDate(Eval("MeetingDate"))) %></span>
                                <span class="wb-dash-time"><%# HttpUtility.HtmlEncode(FormatTime(Eval("MeetingTime"))) %></span>
                            </ItemTemplate>
                        </asp:TemplateField>
                        <asp:TemplateField HeaderText="Submit agenda by">
                            <ItemTemplate>
                                <span class="wb-dash-date"><%# HttpUtility.HtmlEncode(FormatDate(Eval("AgendaSubmissionDate"))) %></span>
                            </ItemTemplate>
                        </asp:TemplateField>
                        <asp:TemplateField HeaderText="Status">
                            <ItemTemplate>
                                <span class='<%# StateCssClass(Eval("StateCode")) %>'><%# HttpUtility.HtmlEncode(Eval("StateLabel")) %></span>
                            </ItemTemplate>
                        </asp:TemplateField>
                        <asp:BoundField DataField="Items" HeaderText="Items" HtmlEncode="true">
                            <ItemStyle CssClass="wb-dash-num" />
                            <HeaderStyle CssClass="wb-dash-num" />
                        </asp:BoundField>
                        <asp:BoundField DataField="Approved" HeaderText="Approved" HtmlEncode="true">
                            <ItemStyle CssClass="wb-dash-num" />
                            <HeaderStyle CssClass="wb-dash-num" />
                        </asp:BoundField>
                        <asp:BoundField DataField="Rejected" HeaderText="Rejected" HtmlEncode="true">
                            <ItemStyle CssClass="wb-dash-num" />
                            <HeaderStyle CssClass="wb-dash-num" />
                        </asp:BoundField>
                        <asp:BoundField DataField="Pending" HeaderText="Pending" HtmlEncode="true">
                            <ItemStyle CssClass="wb-dash-num" />
                            <HeaderStyle CssClass="wb-dash-num" />
                        </asp:BoundField>
                        <%-- Step UN6c2a: for a Controller and a Manager, the items of the meeting that wait for this
                             person's approval (the same rule as the My approvals panel); empty when none. Shown only
                             when the server says so. --%>
                        <asp:TemplateField>
                            <HeaderTemplate><span title="Items of this meeting waiting for your approval">Waiting for me</span></HeaderTemplate>
                            <ItemTemplate><%# HttpUtility.HtmlEncode(WaitingText(Eval("WaitingForMe"))) %></ItemTemplate>
                            <ItemStyle CssClass="wb-dash-num wb-dash-waiting" />
                            <HeaderStyle CssClass="wb-dash-num wb-dash-waiting" />
                        </asp:TemplateField>
                    </Columns>
                </asp:GridView>
            </div>
            <h3 class="wb-section-title">Completed (last 10)</h3>
            <div class="wb-table-scroll">
                <asp:GridView ID="grvCompleted" runat="server" CssClass="wb-table wb-dash-table" AutoGenerateColumns="False"
                    GridLines="None" UseAccessibleHeader="true" EmptyDataText="No completed meetings.">
                    <Columns>
                        <asp:TemplateField HeaderText="Meeting">
                            <ItemTemplate>
                                <span class="wb-dash-committee"><%# HttpUtility.HtmlEncode(Eval("CommitteeName")) %></span>
                                <span class="wb-dash-meeting-no">No <%# HttpUtility.HtmlEncode(Eval("MeetingNo")) %></span>
                            </ItemTemplate>
                        </asp:TemplateField>
                        <asp:TemplateField HeaderText="Meeting date">
                            <ItemTemplate>
                                <span class="wb-dash-date"><%# HttpUtility.HtmlEncode(FormatDate(Eval("MeetingDate"))) %></span>
                                <span class="wb-dash-time"><%# HttpUtility.HtmlEncode(FormatTime(Eval("MeetingTime"))) %></span>
                            </ItemTemplate>
                        </asp:TemplateField>
                        <asp:TemplateField HeaderText="Submit agenda by">
                            <ItemTemplate>
                                <span class="wb-dash-date"><%# HttpUtility.HtmlEncode(FormatDate(Eval("AgendaSubmissionDate"))) %></span>
                            </ItemTemplate>
                        </asp:TemplateField>
                        <asp:TemplateField HeaderText="Status">
                            <ItemTemplate>
                                <span class='<%# StateCssClass(Eval("StateCode")) %>'><%# HttpUtility.HtmlEncode(Eval("StateLabel")) %></span>
                            </ItemTemplate>
                        </asp:TemplateField>
                        <asp:BoundField DataField="Items" HeaderText="Items" HtmlEncode="true">
                            <ItemStyle CssClass="wb-dash-num" />
                            <HeaderStyle CssClass="wb-dash-num" />
                        </asp:BoundField>
                        <asp:BoundField DataField="Approved" HeaderText="Approved" HtmlEncode="true">
                            <ItemStyle CssClass="wb-dash-num" />
                            <HeaderStyle CssClass="wb-dash-num" />
                        </asp:BoundField>
                        <asp:BoundField DataField="Rejected" HeaderText="Rejected" HtmlEncode="true">
                            <ItemStyle CssClass="wb-dash-num" />
                            <HeaderStyle CssClass="wb-dash-num" />
                        </asp:BoundField>
                        <asp:BoundField DataField="Pending" HeaderText="Pending" HtmlEncode="true">
                            <ItemStyle CssClass="wb-dash-num" />
                            <HeaderStyle CssClass="wb-dash-num" />
                        </asp:BoundField>
                    </Columns>
                </asp:GridView>
            </div>
        </asp:Panel>
    </div>
</div>
