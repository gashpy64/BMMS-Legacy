<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="SendMail.aspx.cs" Inherits="BMMS.Report.SendMail" Title="Untitled Page"
    ValidateRequest="false" MaintainScrollPositionOnPostback="true" %>

<%@ Register Assembly="FreeTextBox" Namespace="FreeTextBoxControls" TagPrefix="FTB" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">

    <script language="javascript" type="text/javascript">
    function UploadClick(btnUploadId)
	{
		document.getElementById(btnUploadId).click();  
	}
    </script>

    <asp:Panel ID="pnlMeetingMaster" runat="server">
        <div class="formContent">
            <div class="formPanel">
                <div class="divHeader">
                    :: Send Mail</div>
                <div class="divRowFixed">
                </div>
                <div class="divRow" style="height: 25px">
                    <div id="divErrLogin" runat="server" class="divErrorHide">
                        <span id="spanErrLogin" runat="server" class="lblError"></span>
                    </div>
                </div>
                <div class="divRow">
                    <table border="0" cellpadding="0" cellspacing="12" width="100%">
                        <tr>
                            <td class="Lable" style="width: 30%">
                                Committee :</td>
                            <td>
                                <asp:DropDownList ID="ddlCommittee" runat="server" Width="150px" AutoPostBack="true"
                                    OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                                </asp:DropDownList>&nbsp;
                            </td>
                        </tr>
                        <tr>
                            <td class="Lable" style="width: 30%">
                                Meeting No :</td>
                            <td>
                                <asp:DropDownList ID="ddlMeeting" runat="server" Width="150px" AutoPostBack="true"
                                    OnSelectedIndexChanged="ddlMeeting_SelectedIndexChanged">
                                </asp:DropDownList></td>
                        </tr>
                        <tr>
                            <td valign="top" class="Lable" style="width: 30%">
                                To :</td>
                            <td>
                                <asp:TextBox ID="txtToMailId" runat="server" Height="50px" TextMode="MultiLine" Width="450px"></asp:TextBox>
                            </td>
                        </tr>
                        <tr>
                            <td valign="top" class="Lable" style="width: 30%">
                                Subject :</td>
                            <td>
                                <asp:TextBox ID="txtSubject" runat="server" TextMode="MultiLine" Height="50px" Width="450px"></asp:TextBox>
                            </td>
                        </tr>
                        <tr>
                            <td valign="top" class="Lable" style="width: 30%">
                                Body Text :</td>
                            <td>
                                <FTB:FreeTextBox ID="ftxtBodyText" runat="server" Height="100px" 
                                    AllowHtmlMode="false" ShowTagPath="false"
                                    AutoGenerateToolbarsFromString="True" ButtonSet="Office2003" 
                                    ToolbarLayout="Bold,Italic,Underline|JustifyLeft,JustifyRight,JustifyCenter,JustifyFull;BulletedList,NumberedList,Indent,Outdent"
                                    ToolbarStyleConfiguration="Office2003">
                                </FTB:FreeTextBox>
                            </td>
                        </tr>
                        <tr>
                            <td class="Lable" style="width: 30%">
                                Attachment :</td>
                            <td>
                                <a id="aAttachment" runat="server" target="_blank">View</a>
                                <asp:FileUpload ID="FileUploadAttachment" runat="server" />
                                <asp:Button ID="btnAddAttachment" runat="server" Text="AddAttachment" OnClick="btnAttachment_Click"
                                    Style="visibility: hidden" />
                                <asp:TextBox ID="txtAttachmentPath" runat="server" Width="150px" Style="visibility: hidden"></asp:TextBox>
                                
                            </td>
                        </tr>
                        <tr>
                            <td>
                                &nbsp;</td>
                            <td>
                                <asp:Button ID="btnSendMail" runat="server" Text="Send Mail" OnClick="btnSendMail_Click"
                                    CssClass="button" />
                            </td>
                        </tr>
                    </table>
                </div>
            </div>
        </div>
    </asp:Panel>
</asp:Content>
