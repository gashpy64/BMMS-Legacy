<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="SittingFees.aspx.cs" Inherits="BMMS.Report.SittingFees" Title="Sitting Fees Applicable" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <asp:Panel ID="pnlSittingFees" runat="server">
                <div class="formContent">
                    <div class="formPanel">
                        <div class="divHeader">
                            :: Sitting Fees Reports</div>
                        <div class="divRowFixed">
                        </div>
                        <div class="divRow">
                            <asp:Panel ID="Panel1" runat="server">
                                <table border="0" cellpadding="0" cellspacing="12" width="100%;">
                                    <tr>
                                        <td class="Lable" style="width: 40%; ">
                                            From Date :</td>
                                        <td>
                                            <asp:TextBox ID="txtFromDate" runat="server" Width="100px" onfocus="this.blur();"
                                                TabIndex="-1"></asp:TextBox>
                                            <asp:ImageButton runat="Server" ID="imgFromDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                            <span class="spanMandatory">*</span>
                                            <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender2" runat="server"
                                                TargetControlID="txtFromDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                                PopupButtonID="imgFromDate">
                                            </cc1:CalendarExtender>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td class="Lable" style="width: 40%">
                                            To Date :</td>
                                        <td>
                                            <asp:TextBox ID="txtToDate" runat="server" Width="100px" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                                            <asp:ImageButton runat="Server" ID="imgToDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                            <span class="spanMandatory">*</span>
                                            <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender1" runat="server"
                                                TargetControlID="txtToDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                                PopupButtonID="imgToDate">
                                            </cc1:CalendarExtender>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td class="Lable" style="width: 40%">
                                            Report Type :</td>
                                        <td>
                                            <asp:RadioButtonList ID="rdoReportType" runat="server" AutoPostBack="True" OnSelectedIndexChanged="rdoReportType_SelectedIndexChanged"
                                                RepeatDirection="Horizontal">
                                                <asp:ListItem Text="Individual" Value="Individual" Selected="True"></asp:ListItem>
                                                <asp:ListItem Text="Designation" Value="Designation"></asp:ListItem>
                                                <asp:ListItem Text="Consolidated" Value="Consolidated"></asp:ListItem>
                                            </asp:RadioButtonList>
                                        </td>
                                    </tr>
                                </table>
                            </asp:Panel>
                            <asp:Panel ID="pnlIndividual" runat="server">
                                <table border="0" cellpadding="0" cellspacing="12" width="100%">
                                    <%--<tr>
                                        <td class="Lable" style="width: 40%">
                                            Department :</td>
                                        <td>
                                            <asp:DropDownList ID="ddlDepartment" runat="server" Width="150px" AutoPostBack="true"
                                                OnSelectedIndexChanged="ddlDepartment_SelectedIndexChanged">
                                            </asp:DropDownList></td>
                                    </tr>--%>
                                    <tr>
                                        <td class="Lable" style="width: 40%">
                                            Member :</td>
                                        <td>
                                            <asp:DropDownList ID="ddlMember" runat="server" Width="150px" AutoPostBack="true"
                                                OnSelectedIndexChanged="ddlMember_SelectedIndexChanged">
                                            </asp:DropDownList></td>
                                    </tr>
                                </table>
                            </asp:Panel>
                            <asp:Panel ID="pnlDesignation" runat="server">
                                <table border="0" cellpadding="0" cellspacing="12" width="100%">
                                    <tr>
                                        <td class="Lable" style="width: 40%">
                                            Designation :</td>
                                        <td>
                                            <asp:DropDownList ID="ddlDesignation" runat="server" Width="150px" AutoPostBack="true"
                                                OnSelectedIndexChanged="ddlDesignation_SelectedIndexChanged">
                                            </asp:DropDownList></td>
                                    </tr>
                                </table>
                            </asp:Panel>
                            <asp:Panel ID="pnlConsolidated" runat="server">
                                <table border="0" cellpadding="0" cellspacing="12" width="100%">
                                    <tr>
                                        <td class="Lable" style="width: 40%">
                                            Committee :</td>
                                        <td>
                                            <asp:DropDownList ID="ddlCommittee" runat="server" Width="150px" AutoPostBack="true"
                                                OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                                            </asp:DropDownList></td>
                                    </tr>
                                </table>
                            </asp:Panel>
                        </div>
                        <div class="divRow">
                            <asp:Panel ID="pnlGenerateReport" runat="server">
                                <table border="0" cellpadding="0" cellspacing="12" width="100%">
                                    <tr>
                                        <td class="Lable" style="width: 40%">
                                            Authorized Person Name :</td>
                                        <td>
                                            <asp:TextBox ID="txtAuthorizedPersionName" runat="server" Width="150px"></asp:TextBox>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td class="Lable" style="width: 40%">
                                            Authorized Person Designation :</td>
                                        <td>
                                            <asp:TextBox ID="txtAuthorizedPersionDesign" runat="server" Width="150px"></asp:TextBox>
                                        </td>
                                    </tr>                                
                                    <tr>
                                        <td class="Lable" style="width: 40%">
                                        </td>
                                        <td>
                                            <asp:Button ID="btnGenerateReport" runat="server" Text="Generate Report" OnClick="btnGenerateReport_Click"
                                                CssClass="button" /></td>
                                    </tr>
                                </table>
                            </asp:Panel>
                        </div>
                    </div>
                </div>
            </asp:Panel>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
