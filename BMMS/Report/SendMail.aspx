<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="SendMail.aspx.cs" Inherits="BMMS.Report.SendMail" Title="Untitled Page"
    MaintainScrollPositionOnPostback="true" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">

    <script language="javascript" type="text/javascript">
    function UploadClick(btnUploadId)
	{
		document.getElementById(btnUploadId).click();  
	}
    </script>

    <asp:Panel ID="pnlMeetingMaster" runat="server">
        <%-- Step UI2b: the Masters' form look (Committee Master): breadcrumb and title as in the menu, a card with label
             and field rows, Send Mail as the primary button. The hidden Add Attachment button and the upload script are
             unchanged. Control IDs, events and the handlers are unchanged. --%>
        <div class="wb-page">
            <div class="wb-breadcrumb">
                Reports<span class="wb-breadcrumb-sep">/</span>Send Mail</div>
            <h1 class="wb-h1">
                Send Mail</h1>
            <div aria-live="polite">
                <div id="divErrLogin" runat="server" class="divErrorHide">
                    <span id="spanErrLogin" runat="server" class="lblError"></span>
                </div>
            </div>
            <div class="wb-card">
                <div class="wb-card-header">
                    Mail</div>
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
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtToMailId">
                            To <span class="wb-req">*</span></label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtToMailId" runat="server" TextMode="MultiLine"></asp:TextBox>
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtSubject">
                            Subject</label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtSubject" runat="server" TextMode="MultiLine"></asp:TextBox>
                        </div>
                    </div>
                    <div class="wb-row">
                        <div class="wb-label">
                            Body Text</div>
                        <div class="wb-field">
                            <bmms:RichTextEditor ID="ftxtBodyText" runat="server" Height="100px" Label="Body Text" />
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_FileUploadAttachment">
                            Attachment</label>
                        <div class="wb-field">
                            <a id="aAttachment" runat="server" target="_blank">View</a>
                            <asp:Label ID="lblAttachmentName" runat="server"></asp:Label>
                            <asp:FileUpload ID="FileUploadAttachment" runat="server" />
                            <asp:Button ID="btnAddAttachment" runat="server" Text="AddAttachment" OnClick="btnAttachment_Click"
                                Style="visibility: hidden" />
                        </div>
                    </div>
                    <div class="wb-actions">
                        <asp:Button ID="btnSendMail" runat="server" Text="Send Mail" OnClick="btnSendMail_Click"
                            CssClass="wb-btn" />
                    </div>
                </div>
            </div>
        </div>
    </asp:Panel>
</asp:Content>
