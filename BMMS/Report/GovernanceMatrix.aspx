<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="GovernanceMatrix.aspx.cs" Inherits="BMMS.Report.GovernanceMatrix" Title="Governance Matrix" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<%-- Step GM1a: who enters, approves and confirms each transaction, as on a date, and the governance change log.
     Read only: no control on this page saves anything. Admin and Controller (PageAccess.xml and RequireRole). --%>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="wb-page wb-gov">
        <div class="wb-breadcrumb wb-noprint">
            <asp:Literal ID="litMenuName" runat="server" Text="Reports"></asp:Literal><span class="wb-breadcrumb-sep">/</span>Governance Matrix</div>
        <h1 class="wb-h1">
            Governance Matrix</h1>
        <div class="wb-gov-tabs wb-noprint" role="group" aria-label="View">
            <asp:Button ID="btnTabMatrix" runat="server" CssClass="wb-btn" Text="Matrix" OnClick="btnTabMatrix_Click" />
            <asp:Button ID="btnTabLog" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Change log" OnClick="btnTabLog_Click" />
        </div>
        <div aria-live="polite">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
        </div>

        <%-- The matrix --%>
        <asp:Panel ID="pnlMatrix" runat="server">
            <div class="wb-card wb-noprint">
                <div class="wb-card-body">
                    <div class="wb-toolbar wb-gov-filters">
                        <div class="wb-filter">
                            <label class="wb-label" for="<%= txtAsOn.ClientID %>">As on</label>
                            <asp:TextBox ID="txtAsOn" runat="server" CssClass="wb-gov-date-input" autocomplete="off" MaxLength="11"></asp:TextBox>
                            <cc1:CalendarExtender CssClass="cal_Theme1" ID="calAsOn" runat="server" TargetControlID="txtAsOn"
                                Format="dd-MMM-yyyy" PopupPosition="BottomLeft">
                            </cc1:CalendarExtender>
                        </div>
                        <div class="wb-filter">
                            <label class="wb-label" for="<%= ddlDepartment.ClientID %>">Department</label>
                            <asp:DropDownList ID="ddlDepartment" runat="server" autocomplete="off"></asp:DropDownList>
                        </div>
                        <div class="wb-filter">
                            <label class="wb-label" for="<%= ddlTransaction.ClientID %>">Transaction</label>
                            <asp:DropDownList ID="ddlTransaction" runat="server" autocomplete="off"></asp:DropDownList>
                        </div>
                        <div class="wb-filter wb-gov-show">
                            <asp:Button ID="btnShow" runat="server" CssClass="wb-btn" Text="Show" OnClick="btnShow_Click" />
                        </div>
                    </div>
                    <p class="wb-help">
                        Date as dd-MMM-yyyy, for example 25-Nov-2026; click the box to pick a date. The matrix shows the state at the end of that day.</p>
                </div>
            </div>
            <asp:Panel ID="pnlMatrixResult" runat="server" Visible="false">
                <p class="wb-gov-asof"><asp:Literal ID="litAsOn" runat="server"></asp:Literal></p>
                <asp:Literal ID="litMatrixNotes" runat="server"></asp:Literal>
                <div class="wb-actions wb-noprint">
                    <asp:Button ID="btnPrintMatrix" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Print" OnClientClick="window.print(); return false;" UseSubmitBehavior="false" />
                    <asp:Button ID="btnExcelMatrix" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Export to Excel (CSV)" OnClick="btnExcelMatrix_Click" />
                    <asp:Button ID="btnPdfMatrix" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Export to PDF" OnClick="btnPdfMatrix_Click" />
                </div>
                <div class="wb-card">
                    <div class="wb-card-header">
                        Settings</div>
                    <div class="wb-card-body">
                        <div class="wb-table-scroll">
                        <asp:GridView ID="grvSettings" runat="server" AutoGenerateColumns="false" CssClass="wb-table" GridLines="None">
                            <Columns>
                                <asp:BoundField DataField="Setting" HeaderText="Setting" />
                                <asp:BoundField DataField="Value" HeaderText="Value" />
                            </Columns>
                        </asp:GridView>
                        </div>
                    </div>
                </div>
                <div class="wb-card">
                    <div class="wb-card-header">
                        Who enters and who approves</div>
                    <div class="wb-card-body">
                        <div class="wb-table-scroll">
                            <asp:GridView ID="grvMatrix" runat="server" AutoGenerateColumns="false" CssClass="wb-table wb-gov-table wb-gov-matrix" GridLines="None">
                                <Columns>
                                    <asp:BoundField DataField="Transaction" HeaderText="Transaction" ItemStyle-CssClass="wb-gov-tx" />
                                    <asp:BoundField DataField="Department" HeaderText="Department" ItemStyle-CssClass="wb-gov-dept" />
                                    <asp:BoundField DataField="WhoEnters" HeaderText="Who enters" />
                                    <asp:BoundField DataField="WhoApproves" HeaderText="Who approves" />
                                    <asp:BoundField DataField="Controllers" HeaderText="Controller(s)" />
                                    <asp:BoundField DataField="RuleNote" HeaderText="Rule note" ItemStyle-CssClass="wb-gov-note" />
                                </Columns>
                                <EmptyDataTemplate>
                                    No rows for the chosen filters.
                                </EmptyDataTemplate>
                            </asp:GridView>
                        </div>
                    </div>
                </div>
                <div class="wb-card">
                    <div class="wb-card-header">
                        Read-only access</div>
                    <div class="wb-card-body">
                        <div class="wb-table-scroll">
                        <asp:GridView ID="grvReadOnly" runat="server" AutoGenerateColumns="false" CssClass="wb-table wb-gov-table wb-gov-readonly" GridLines="None">
                            <Columns>
                                <asp:BoundField DataField="Role" HeaderText="Role" ItemStyle-CssClass="wb-gov-dept" />
                                <asp:BoundField DataField="People" HeaderText="People" />
                                <asp:BoundField DataField="CanRead" HeaderText="Can read" />
                            </Columns>
                        </asp:GridView>
                        </div>
                        <p class="wb-help">
                            From the menu and the page rules. These roles approve nothing.</p>
                    </div>
                </div>
            </asp:Panel>
        </asp:Panel>

        <%-- The change log --%>
        <asp:Panel ID="pnlLog" runat="server" Visible="false">
            <div class="wb-card wb-noprint">
                <div class="wb-card-body">
                    <div class="wb-toolbar wb-gov-filters">
                        <div class="wb-filter">
                            <label class="wb-label" for="<%= txtFrom.ClientID %>">From</label>
                            <asp:TextBox ID="txtFrom" runat="server" CssClass="wb-gov-date-input" autocomplete="off" MaxLength="11"></asp:TextBox>
                            <cc1:CalendarExtender CssClass="cal_Theme1" ID="calFrom" runat="server" TargetControlID="txtFrom"
                                Format="dd-MMM-yyyy" PopupPosition="BottomLeft">
                            </cc1:CalendarExtender>
                        </div>
                        <div class="wb-filter">
                            <label class="wb-label" for="<%= txtTo.ClientID %>">To</label>
                            <asp:TextBox ID="txtTo" runat="server" CssClass="wb-gov-date-input" autocomplete="off" MaxLength="11"></asp:TextBox>
                            <cc1:CalendarExtender CssClass="cal_Theme1" ID="calTo" runat="server" TargetControlID="txtTo"
                                Format="dd-MMM-yyyy" PopupPosition="BottomLeft">
                            </cc1:CalendarExtender>
                        </div>
                        <div class="wb-filter">
                            <label class="wb-label" for="<%= ddlLogUser.ClientID %>">User</label>
                            <asp:DropDownList ID="ddlLogUser" runat="server" CssClass="wb-user-select" autocomplete="off"></asp:DropDownList>
                        </div>
                        <div class="wb-filter">
                            <label class="wb-label" for="<%= ddlLogDepartment.ClientID %>">Department</label>
                            <asp:DropDownList ID="ddlLogDepartment" runat="server" autocomplete="off"></asp:DropDownList>
                        </div>
                        <div class="wb-filter">
                            <label class="wb-label" for="<%= ddlChangeType.ClientID %>">Change type</label>
                            <asp:DropDownList ID="ddlChangeType" runat="server" autocomplete="off"></asp:DropDownList>
                        </div>
                        <div class="wb-filter wb-gov-show">
                            <asp:Button ID="btnShowLog" runat="server" CssClass="wb-btn" Text="Show" OnClick="btnShowLog_Click" />
                        </div>
                    </div>
                </div>
            </div>
            <asp:Panel ID="pnlLogResult" runat="server" Visible="false">
                <p class="wb-gov-asof"><asp:Literal ID="litLogRange" runat="server"></asp:Literal></p>
                <div class="wb-actions wb-noprint">
                    <asp:Button ID="btnPrintLog" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Print" OnClientClick="window.print(); return false;" UseSubmitBehavior="false" />
                    <asp:Button ID="btnExcelLog" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Export to Excel (CSV)" OnClick="btnExcelLog_Click" />
                    <asp:Button ID="btnPdfLog" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Export to PDF" OnClick="btnPdfLog_Click" />
                </div>
                <div class="wb-card">
                    <div class="wb-card-header">
                        Change log</div>
                    <div class="wb-card-body">
                        <div class="wb-table-scroll">
                            <asp:GridView ID="grvLog" runat="server" AutoGenerateColumns="false" CssClass="wb-table wb-gov-table wb-gov-log" GridLines="None">
                                <Columns>
                                    <asp:BoundField DataField="ChangedOnText" HeaderText="Changed on" ItemStyle-CssClass="wb-gov-date" />
                                    <asp:BoundField DataField="ChangedByText" HeaderText="Changed by" />
                                    <asp:BoundField DataField="ChangeText" HeaderText="Change" />
                                    <asp:BoundField DataField="UserText" HeaderText="User" />
                                    <asp:BoundField DataField="SubjectText" HeaderText="Department or setting" />
                                    <asp:BoundField DataField="OldText" HeaderText="Old value" />
                                    <asp:BoundField DataField="NewText" HeaderText="New value" />
                                    <asp:BoundField DataField="SourceText" HeaderText="Source" />
                                </Columns>
                                <EmptyDataTemplate>
                                    No changes for the chosen filters.
                                </EmptyDataTemplate>
                            </asp:GridView>
                        </div>
                    </div>
                </div>
            </asp:Panel>
        </asp:Panel>
    </div>
</asp:Content>
