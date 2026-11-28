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
                <%-- Step UI2b: the Masters' form look (Committee Master): breadcrumb and title as in the menu, a Filter card and a
                     Notice details card with Create PDF as the primary button and Send Mail as the secondary one. Control IDs,
                     panels, events and the handlers are unchanged. --%>
                <div class="wb-page">
                    <div class="wb-breadcrumb">
                        Reports<span class="wb-breadcrumb-sep">/</span>Notice</div>
                    <h1 class="wb-h1">
                        Notice</h1>
                    <div aria-live="polite">
                        <div id="divErrLogin" runat="server" class="divErrorHide">
                            <span id="spanErrLogin" runat="server" class="lblError"></span>
                        </div>
                    </div>
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
                        </div>
                    </div>
                    <asp:Panel ID="pnlNoticeDetails" runat="server" Visible="false">
                        <div class="wb-card">
                            <div class="wb-card-header">
                                Notice details</div>
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
                                    <asp:Button ID="btnSendMail" runat="server" Text="Send Mail" OnClick="btnSendMail_Click"
                                        CssClass="wb-btn wb-btn-secondary" />
                                </div>
                                <asp:Panel ID="pnlNoticeDownload" runat="server" Visible="false">
                                    The notice opened in a new window; allow pop-ups if it did not.
                                </asp:Panel>
                            </div>
                        </div>
                    </asp:Panel>
                </div>
            </asp:Panel>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
