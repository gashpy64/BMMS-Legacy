<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="SittingFees.aspx.cs" Inherits="BMMS.Report.SittingFees" Title="Sitting Fees Applicable" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <asp:Panel ID="pnlSittingFees" runat="server">
                <%-- Step UI2b: the Masters' form look (Committee Master): breadcrumb and title as in the menu, a Filter
                     card (dates, report type and the three type panels) and a Signatory card with Generate Report as
                     the primary button. Control IDs, panels, events and the handlers are unchanged. --%>
                <div class="wb-page">
                    <div class="wb-breadcrumb">
                        Reports<span class="wb-breadcrumb-sep">/</span>Sitting Fees</div>
                    <h1 class="wb-h1">
                        Sitting Fees</h1>
                    <div class="wb-card">
                        <div class="wb-card-header">
                            Filter</div>
                        <div class="wb-card-body">
                            <asp:Panel ID="Panel1" runat="server">
                                <div class="wb-row">
                                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtFromDate">
                                        From Date <span class="wb-req">*</span></label>
                                    <div class="wb-field">
                                        <asp:TextBox ID="txtFromDate" runat="server" onfocus="this.blur();"
                                            TabIndex="-1"></asp:TextBox>
                                        <asp:ImageButton runat="Server" ID="imgFromDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                        <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender2" runat="server"
                                            TargetControlID="txtFromDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                            PopupButtonID="imgFromDate">
                                        </cc1:CalendarExtender>
                                    </div>
                                </div>
                                <div class="wb-row">
                                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtToDate">
                                        To Date <span class="wb-req">*</span></label>
                                    <div class="wb-field">
                                        <asp:TextBox ID="txtToDate" runat="server" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                                        <asp:ImageButton runat="Server" ID="imgToDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                        <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender1" runat="server"
                                            TargetControlID="txtToDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                            PopupButtonID="imgToDate">
                                        </cc1:CalendarExtender>
                                    </div>
                                </div>
                                <div class="wb-row">
                                    <div class="wb-label">
                                        Report Type</div>
                                    <div class="wb-field">
                                        <asp:RadioButtonList ID="rdoReportType" runat="server" AutoPostBack="True" OnSelectedIndexChanged="rdoReportType_SelectedIndexChanged"
                                            RepeatDirection="Horizontal" CssClass="wb-radio-list">
                                            <asp:ListItem Text="Individual" Value="Individual" Selected="True"></asp:ListItem>
                                            <asp:ListItem Text="Designation" Value="Designation"></asp:ListItem>
                                            <asp:ListItem Text="Consolidated" Value="Consolidated"></asp:ListItem>
                                        </asp:RadioButtonList>
                                    </div>
                                </div>
                            </asp:Panel>
                            <asp:Panel ID="pnlIndividual" runat="server">
                                <%--<div class="wb-row">
                                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlDepartment">
                                        Department</label>
                                    <div class="wb-field">
                                        <asp:DropDownList ID="ddlDepartment" runat="server" AutoPostBack="true"
                                            OnSelectedIndexChanged="ddlDepartment_SelectedIndexChanged">
                                        </asp:DropDownList>
                                    </div>
                                </div>--%>
                                <div class="wb-row">
                                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlMember">
                                        Member</label>
                                    <div class="wb-field">
                                        <asp:DropDownList ID="ddlMember" runat="server" AutoPostBack="true"
                                            OnSelectedIndexChanged="ddlMember_SelectedIndexChanged">
                                        </asp:DropDownList>
                                    </div>
                                </div>
                            </asp:Panel>
                            <asp:Panel ID="pnlDesignation" runat="server">
                                <div class="wb-row">
                                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlDesignation">
                                        Designation</label>
                                    <div class="wb-field">
                                        <asp:DropDownList ID="ddlDesignation" runat="server" AutoPostBack="true"
                                            OnSelectedIndexChanged="ddlDesignation_SelectedIndexChanged">
                                        </asp:DropDownList>
                                    </div>
                                </div>
                            </asp:Panel>
                            <asp:Panel ID="pnlConsolidated" runat="server">
                                <div class="wb-row">
                                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlCommittee">
                                        Committee</label>
                                    <div class="wb-field">
                                        <asp:DropDownList ID="ddlCommittee" runat="server" AutoPostBack="true"
                                            OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                                        </asp:DropDownList>
                                    </div>
                                </div>
                            </asp:Panel>
                        </div>
                    </div>
                    <asp:Panel ID="pnlGenerateReport" runat="server">
                        <div class="wb-card">
                            <div class="wb-card-header">
                                Signatory</div>
                            <div class="wb-card-body">
                                <div class="wb-row">
                                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtAuthorizedPersionName">
                                        Authorized Person Name</label>
                                    <div class="wb-field">
                                        <asp:TextBox ID="txtAuthorizedPersionName" runat="server"></asp:TextBox>
                                    </div>
                                </div>
                                <div class="wb-row">
                                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtAuthorizedPersionDesign">
                                        Authorized Person Designation</label>
                                    <div class="wb-field">
                                        <asp:TextBox ID="txtAuthorizedPersionDesign" runat="server"></asp:TextBox>
                                    </div>
                                </div>
                                <div class="wb-actions">
                                    <asp:Button ID="btnGenerateReport" runat="server" Text="Generate Report" OnClick="btnGenerateReport_Click"
                                        CssClass="wb-btn" />
                                </div>
                            </div>
                        </div>
                    </asp:Panel>
                </div>
            </asp:Panel>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
