<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="Notice.aspx.cs" Inherits="BMMS.Report.Notice" Title="Untitled Page" %>

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
                <div class="formContent">
                <div class="formPanel">
                    <div class="divHeader">
                    :: Notice Report</div>
                    <div class="divRowFixed"></div>
                    <div class="divRow" style="height: 25px">
                        <div id="divErrLogin" runat="server" class="divErrorHide">
                            <span id="spanErrLogin" runat="server" class="lblError"></span>
                        </div>
                    </div>
                    <div class="divRow">
                    <table border="0" cellpadding="0" cellspacing="12" width="100%">
                        <tr>
                            <td class="Lable" width="30%">
                                Committee :</td>
                            <td>
                                <asp:DropDownList ID="ddlCommittee" runat="server" Width="150px" AutoPostBack="true"
                                    OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                                </asp:DropDownList>&nbsp;
                            </td>
                        </tr>
                        <tr>
                            <td class="Lable" width="30%">
                                Meeting No :</td>
                            <td>
                                <asp:DropDownList ID="ddlMeeting" runat="server" Width="150px" AutoPostBack="true"
                                    OnSelectedIndexChanged="ddlMeeting_SelectedIndexChanged">
                                </asp:DropDownList></td>
                        </tr>
                    </table>
                    <asp:Panel ID="pnlNoticeDetails" runat="server" Visible="false">
                        <table border="0" cellpadding="0" cellspacing="12" width="100%">
                            <tr>
                                <td class="Lable" width="30%">
                                    Meeting Venue :</td>
                                <td>
                                    <asp:TextBox ID="txtMeetingVenue" runat="server" TextMode="MultiLine" Height="50px"></asp:TextBox>
                                </td>
                            </tr>
                            <tr>
                                <td class="Lable" width="30%">
                                    Meeting Date :</td>
                                <td>
                                    <asp:TextBox ID="txtMeetingDate" runat="server"></asp:TextBox>
                                </td>
                            </tr>
                            <tr>
                                <td class="Lable" width="30%">
                                    Meeting Time :</td>
                                <td>
                                    <asp:TextBox ID="txtMeetingTime" CssClass="txtTimeFormat" runat="server"></asp:TextBox>
                                    Hrs.
                                </td>
                            </tr>
                            <tr>
                                <td>
                                    &nbsp;</td>
                                <td>
                                    <asp:Button ID="btnCreatePDF" runat="server" Text="Create PDF" OnClick="btnCreatePDF_Click"
                                        CssClass="button" />
                                    <asp:Button ID="btnSendMail" runat="server" Text="Send Mail" OnClick="btnSendMail_Click"
                                        CssClass="button" />
                                </td>
                            </tr>
                            <tr>
                                <td>
                                    &nbsp;</td>
                                <td>
                                    <asp:Panel ID="pnlNoticeDownload" runat="server" Visible="false">
                                        <a href="../Files/PDF/Notice.pdf" target="_blank">Download Notice</a>
                                    </asp:Panel>
                                </td>
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
