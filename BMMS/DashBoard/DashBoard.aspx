<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="DashBoard.aspx.cs" Inherits="BMMS.DashBoard.DashBoard" Title="Untitled Page"
    ValidateRequest="false" %>

<%@ Register Src="../UserControl/MeetingSummary.ascx" TagName="MeetingSummary" TagPrefix="uc1" %>
<%@ Register Assembly="FreeTextBox" Namespace="FreeTextBoxControls" TagPrefix="FTB" %>
<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <table width="100%" border="0" cellspacing="0" cellpadding="0">
                <tr>
                    <td class="leftCol" valign="top">
                        <uc1:MeetingSummary ID="MeetingSummary1" runat="server"></uc1:MeetingSummary>
                        <td valign="top">
                            <div class="formPanel">
                                <div>
                                    <table width="100%" border="0" cellspacing="0" cellpadding="0">
                                        <tr>
                                            <td class="h1Header">
                                                :: Alert</td>
                                            <td class="showAll">
                                                <asp:LinkButton runat="server" ID="lnkShowAll" OnClick="lnkShowAll_Click">Show All</asp:LinkButton>
                                                |
                                                <asp:LinkButton runat="server" ID="lnkRead" OnClick="lnkRead_Click">Read</asp:LinkButton>
                                                |
                                                <asp:LinkButton runat="server" ID="lnkUnread" OnClick="lnkUnread_Click">Unread</asp:LinkButton></td>
                                        </tr>
                                    </table>
                                </div>
                                <div style="margin: 12px; height: 210px; overflow: auto">
                                    <asp:HiddenField ID="hdnAlertUserId" runat="server" />
                                    <asp:Button ID="btnShowPopup" runat="server" Style="display: none" />
                                    <asp:GridView ID="grvAlert" runat="server" Width="100%" CellPadding="4" CssClass="contentTable1"
                                        AutoGenerateColumns="false" OnRowDataBound="grvAlert_RowDataBound" AllowPaging="True"
                                        OnPageIndexChanging="OnPaging" PageSize="10">
                                        <Columns>
                                            <asp:TemplateField HeaderText="Source">
                                                <ItemTemplate>
                                                    <asp:LinkButton ID="lnkSource" runat="server" Text='<%#Bind("DisplayText") %>' OnClick="lnkSource_Click">
                                                    </asp:LinkButton>
                                                    <asp:Label ID="lblSourceType" runat="server" Text='<%#Bind("SourceType") %>' Visible="false"></asp:Label>
                                                    <asp:Label ID="lblSourceTypeId" runat="server" Text='<%#Bind("SourceTypeId") %>'
                                                        Visible="false"></asp:Label>
                                                    <asp:Label ID="lblAlertUserId" runat="server" Text='<%#Bind("AlertUserId") %>' Visible="false"></asp:Label>
                                                    <asp:Label ID="lblAlert" runat="server" Text='<%#Bind("AlertId") %>' Visible="false"></asp:Label>
                                                </ItemTemplate>
                                            </asp:TemplateField>
                                            <asp:TemplateField HeaderText="Department">
                                                <ItemTemplate>
                                                    <asp:Label ID="lblDepartmentName" runat="server" Text='<%#Bind("DepartmentName") %>'></asp:Label>
                                                </ItemTemplate>
                                            </asp:TemplateField>
                                            <asp:TemplateField HeaderText="Alert Type">
                                                <ItemTemplate>
                                                    <asp:Label ID="lblAlertTypeName" runat="server" Text='<%#Bind("AlertTypeName") %>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle Width="100px" VerticalAlign="Middle" HorizontalAlign="Center" />
                                            </asp:TemplateField>
                                            <asp:BoundField DataField="CommitteeName" HeaderText="Committee" SortExpression="CommitteeName" />
                                            <asp:TemplateField HeaderText="CreatedOn">
                                                <ItemTemplate>
                                                    <asp:Label ID="lblCreatedOn" runat="server" Text='<%#Bind("CreatedOn") %>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle Width="100px" VerticalAlign="Middle" HorizontalAlign="Center" />
                                            </asp:TemplateField>
                                            <asp:TemplateField HeaderText="Read" Visible="False">
                                                <ItemTemplate>
                                                    <asp:Label ID="lblRead" runat="server" Text='<%#Eval("ReadStatus") %>'></asp:Label>
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
                                <div style="height: 40px">
                                    <table width="100%" border="0" cellspacing="0" cellpadding="0">
                                        <tr>
                                            <td class="h1Header">
                                                :: Action Item</td>
                                            <td class="showAll">
                                                <asp:LinkButton runat="server" ID="lnkActShowall" OnClick="lnkActShowall_Click">Show All</asp:LinkButton>
                                                |
                                                <asp:LinkButton runat="server" ID="lnkActRead" OnClick="lnkActRead_Click">Read</asp:LinkButton>
                                                |
                                                <asp:LinkButton runat="server" ID="lnkActUnRead" OnClick="lnkActUnRead_Click">Unread</asp:LinkButton></td>
                                        </tr>
                                    </table>
                                </div>
                                <div style="margin: 12px; height: 210px; overflow: auto">
                                    <asp:GridView ID="grvActionItem" runat="server" Width="100%" CellPadding="4" CssClass="contentTable1"
                                        AutoGenerateColumns="false" OnRowDataBound="grvActionItem_RowDataBound" OnPageIndexChanging="OnPagingAction"
                                        AllowPaging="True" PageSize="10">
                                        <Columns>
                                            <asp:TemplateField HeaderText="Committee">
                                                <ItemTemplate>
                                                    <asp:LinkButton ID="lnkActionItem" runat="server" Text='<%#Bind("CommitteeName") %>'
                                                        OnClick="lnkActionItem_Click">
                                                    </asp:LinkButton>
                                                    <asp:Label ID="lblActionItemId" runat="server" Text='<%#Bind("ActionItemId") %>'
                                                        Visible="false"></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle VerticalAlign="Middle" HorizontalAlign="Left" />
                                            </asp:TemplateField>
                                            <asp:TemplateField HeaderText="Agenda No" Visible="true">
                                                <ItemTemplate>
                                                    <asp:Label ID="lblAgendaNo" runat="server" Text='<%#Eval("AgendaNo") %>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle VerticalAlign="Middle" HorizontalAlign="Center" />
                                            </asp:TemplateField>
                                            <asp:TemplateField HeaderText="Subject No" Visible="true">
                                                <ItemTemplate>
                                                    <asp:Label ID="lblSubjectNo" runat="server" Text='<%#Eval("SubjectNo") %>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle VerticalAlign="Middle" HorizontalAlign="Center" />
                                            </asp:TemplateField>
                                            <asp:TemplateField HeaderText="Meeting Date" Visible="true">
                                                <ItemTemplate>
                                                    <asp:Label ID="lblMeetingDate" runat="server" Text='<%#Eval("MeetingDate","{0:dd/MM/yyyy}") %>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle Width="100px" Height="35px" VerticalAlign="Middle" HorizontalAlign="Center" />
                                            </asp:TemplateField>
                                            <asp:TemplateField HeaderText="Decision Type" Visible="true">
                                                <ItemTemplate>
                                                    <asp:Label ID="lblDecisionTypeName" runat="server" Text='<%#Eval("DecisionTypeName") %>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle VerticalAlign="Middle" HorizontalAlign="Center" />
                                            </asp:TemplateField>
                                            <%--<asp:TemplateField HeaderText="DueDate" Visible="true">
                                                <ItemTemplate>
                                                    <asp:Label ID="lblDueDate" runat="server" Text='<%#Eval("DueDate","{0:dd/MM/yyyy}") %>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle VerticalAlign="Middle" HorizontalAlign="Center" />
                                            </asp:TemplateField>--%>
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
                                <br />
                                <cc1:ModalPopupExtender ID="MpCommittee" TargetControlID="btnShowPopup" runat="server"
                                    PopupControlID="pnlAlert" BackgroundCssClass="modalBackground">
                                </cc1:ModalPopupExtender>
                                <asp:Panel ID="pnlAlert" runat="server" Width="610px" Style="height: 500px;">
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
                                            <asp:Button ID="btnDeleteAlert" runat="server" Text="Delete" CssClass="button" OnClick="btnDeleteAlert_Click" />
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
                            </div>
                        </td>
                </tr>
            </table>
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
                        <div class="formContent">
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
                                        <div class="divRowLeft" style="width: 165px;">
                                            Short Text :
                                        </div>
                                        <div class="divRowRight" style="width: 550px;">
                                            <asp:TextBox ID="txtShortText" runat="server" ReadOnly="true" TextMode="MultiLine"
                                                Height="100px" Width="550px"></asp:TextBox>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRowLeft" style="width: 165px;">
                                            Agenda Text :
                                        </div>
                                        <div class="divRowRight" style="width: 550px;">
                                            <FTB:FreeTextBox ID="ftxtAgendaText" runat="server" Width="550px" Height="100px"
                                                AllowHtmlMode="false" ShowTagPath="false" AutoGenerateToolbarsFromString="True"
                                                ButtonSet="Office2003" ToolbarLayout="Bold,Italic,Underline|JustifyLeft,JustifyRight,JustifyCenter,JustifyFull;BulletedList,NumberedList,Indent,Outdent"
                                                ToolbarStyleConfiguration="Office2003">
                                            </FTB:FreeTextBox>
                                            <a id="aAgendaText" runat="server" target="_blank">View</a>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRowLeft" style="width: 165px;">
                                            Proposed Resolution :
                                        </div>
                                        <div class="divRowRight" style="width: 550px;">
                                            <%--<asp:TextBox ID="txtProposedResolution" runat="server" ReadOnly="true" TextMode="MultiLine"
                                            Height="100px" Width="550px"></asp:TextBox>--%>
                                            <FTB:FreeTextBox ID="ftxtProposedResolution" runat="server" Width="550px" Height="100px"
                                                AllowHtmlMode="false" ShowTagPath="false" AutoGenerateToolbarsFromString="True"
                                                ButtonSet="Office2003" ToolbarLayout="Bold,Italic,Underline|JustifyLeft,JustifyRight,JustifyCenter,JustifyFull;BulletedList,NumberedList,Indent,Outdent"
                                                ToolbarStyleConfiguration="Office2003">
                                            </FTB:FreeTextBox>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRowLeft" style="width: 165px;">
                                            Files to be Attached :
                                        </div>
                                        <div class="divRowRight" style="width: 550px;">
                                            <asp:GridView ID="grvAttachedFiles" runat="server" AutoGenerateColumns="False" ShowHeader="False"
                                                BackColor="#DEBA84" BorderColor="#DEBA84" BorderStyle="None" BorderWidth="1px"
                                                CellPadding="3" CellSpacing="2">
                                                <Columns>
                                                    <asp:TemplateField SortExpression="FilePath">
                                                        <ItemTemplate>
                                                            <a href='<%#Eval("FilePath") %>' target="_blank">
                                                                <%#Eval("DisplayName") %>
                                                            </a>
                                                        </ItemTemplate>
                                                    </asp:TemplateField>
                                                </Columns>
                                                <RowStyle BackColor="#FFF7E7" ForeColor="#8C4510" />
                                                <FooterStyle BackColor="#F7DFB5" ForeColor="#8C4510" />
                                                <PagerStyle ForeColor="#8C4510" HorizontalAlign="Center" />
                                                <SelectedRowStyle BackColor="#738A9C" Font-Bold="True" ForeColor="White" />
                                                <HeaderStyle BackColor="#A55129" Font-Bold="True" ForeColor="White" />
                                            </asp:GridView>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRowLeft" style="width: 165px;">
                                            Manager Comments :
                                        </div>
                                        <div class="divRowRight" style="width: 550px;">
                                            <FTB:FreeTextBox ID="ftxtManagerComments" runat="server" Width="550px" Height="100px"
                                                AllowHtmlMode="false" ShowTagPath="false" AutoGenerateToolbarsFromString="True"
                                                ButtonSet="Office2003" ToolbarLayout="Bold,Italic,Underline|JustifyLeft,JustifyRight,JustifyCenter,JustifyFull;BulletedList,NumberedList,Indent,Outdent"
                                                ToolbarStyleConfiguration="Office2003">
                                            </FTB:FreeTextBox>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRowLeft" style="width: 165px;">
                                            Controller Comments :
                                        </div>
                                        <div class="divRowRight" style="width: 550px;">
                                            <FTB:FreeTextBox ID="ftxtControllerComments" runat="server" Width="550px" Height="100px"
                                                AllowHtmlMode="false" ShowTagPath="false" AutoGenerateToolbarsFromString="True"
                                                ButtonSet="Office2003" ToolbarLayout="Bold,Italic,Underline|JustifyLeft,JustifyRight,JustifyCenter,JustifyFull;BulletedList,NumberedList,Indent,Outdent"
                                                ToolbarStyleConfiguration="Office2003">
                                            </FTB:FreeTextBox>
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
                                                    Text="Delete" />
                                            </asp:Panel>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="MyPopupOuter">
                    </div>
            </asp:Panel>
            <asp:Panel ID="pnlActionItemDetails" runat="server" Style="background-color: White;">
                <div class="MyPopupOuter">
                    <div class="MyPopupContent">
                        <div class="formContent">
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
                                        <div class="divRowLeft" style="width: 165px;">
                                            Actual Resolution :
                                        </div>
                                        <div class="divRowRight" style="width: 550px;">
                                            <FTB:FreeTextBox ID="ftxtActualResolution" runat="server" Width="550px" Height="100px"
                                                ReadOnly="true" AllowHtmlMode="false" ShowTagPath="false" AutoGenerateToolbarsFromString="True"
                                                ButtonSet="Office2003" ToolbarLayout="Bold,Italic,Underline|JustifyLeft,JustifyRight,JustifyCenter,JustifyFull;BulletedList,NumberedList,Indent,Outdent"
                                                ToolbarStyleConfiguration="Office2003">
                                            </FTB:FreeTextBox>
                                        </div>
                                    </div>
                                    <div class="divRow">
                                        <div class="divRowLeft" style="width: 165px;">
                                            Action Text :
                                        </div>
                                        <div class="divRowRight" style="width: 550px;">
                                            <FTB:FreeTextBox ID="ftxtActionText" runat="server" Width="550px" Height="100px"
                                                ReadOnly="true" AllowHtmlMode="false" ShowTagPath="false" AutoGenerateToolbarsFromString="True"
                                                ButtonSet="Office2003" ToolbarLayout="Bold,Italic,Underline|JustifyLeft,JustifyRight,JustifyCenter,JustifyFull;BulletedList,NumberedList,Indent,Outdent"
                                                ToolbarStyleConfiguration="Office2003">
                                            </FTB:FreeTextBox>
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
