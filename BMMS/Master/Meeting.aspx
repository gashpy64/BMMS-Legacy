<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="Meeting.aspx.cs" Inherits="BMMS.Master.Meeting" Title="Untitled Page" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <link rel="stylesheet" href="../JScript/ColorPicker/js_color_picker_v2.css" media="screen">

    <script src="../JScript/ColorPicker/color_functions.js"></script>

    <script type="text/javascript" src="../JScript/ColorPicker/js_color_picker_v2.js"></script>

    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <div class="wb-page">
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
                <div class="wb-breadcrumb">
                    Master<span class="wb-breadcrumb-sep">/</span>Meeting Master</div>
                <h1 class="wb-h1">
                    Meeting Master</h1>
                <div aria-live="polite">
                    <div id="divErrLogin" runat="server" class="divErrorHide">
                        <span id="spanErrLogin" runat="server" class="lblError"></span>
                    </div>
                </div>
                <asp:Panel ID="pnlViewMeeting" runat="server">
                    <div class="wb-card">
                        <div class="wb-card-header">
                            Meetings</div>
                        <div class="wb-toolbar">
                            <div class="wb-filter">
                                <label for="ctl00_ContentPlaceHolder1_ddlCommitteeSearch">
                                    Committee Name</label>
                                <asp:DropDownList ID="ddlCommitteeSearch" runat="server" AutoPostBack="true" OnSelectedIndexChanged="ddlCommitteeSearch_SelectedIndexChanged">
                                </asp:DropDownList>
                            </div>
                            <asp:Button ID="btnAdd" runat="server" CssClass="wb-btn" Text="Add" OnClick="btnAdd_Click" />
                        </div>
                        <div class="wb-table-scroll">
                            <asp:GridView ID="grvMeeting" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                                CssClass="wb-table wb-table-wide" AllowSorting="true" DataKeyNames="MeetingId"
                                GridLines="None" OnRowDataBound="grvMeeting_RowDataBound" OnSorting="grvRecord_Sorting"
                                OnRowCommand="grvMeeting_RowCommand">
                                <Columns>
                                    <asp:TemplateField HeaderText="S.No.">
                                        <ItemTemplate>
                                            <%# Container.DataItemIndex+1 + "."%>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="wb-col-action" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="MeetingNo">
                                        <HeaderTemplate>
                                            <asp:LinkButton ID="lnk1" runat="server" Text="Meeting No" CommandName="Sort" CommandArgument="MeetingNo"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblMeetingNoe" SkinID="lblSkinGen" Text='<%# HttpUtility.HtmlEncode(Eval("MeetingNo")) %>' runat="server" />
                                            <asp:HiddenField ID="hdnMeetingNo" runat="server" />
                                        </ItemTemplate>
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="CommitteeName">
                                        <HeaderTemplate>
                                            <asp:LinkButton ID="lnk2" runat="server" Text="Committee Name" CommandName="Sort"
                                                CommandArgument="CommitteeName"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblCommitteeName" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("CommitteeName")) %>'></asp:Label>
                                        </ItemTemplate>
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="Place">
                                        <HeaderTemplate>
                                            <asp:LinkButton ID="lnk3" runat="server" Text="Place" CommandName="Sort" CommandArgument="Place"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblPlace" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("Place")) %>'></asp:Label>
                                        </ItemTemplate>
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="Venue">
                                        <HeaderTemplate>
                                            <asp:LinkButton ID="lnk7" runat="server" Text="Venue" CommandName="Sort" CommandArgument="Venue"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblVenue" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("Venue")) %>'></asp:Label>
                                        </ItemTemplate>
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="MeetingDate">
                                        <HeaderTemplate>
                                            <asp:LinkButton ID="lnk4" runat="server" Text="Meeting Date" CommandName="Sort" CommandArgument="MeetingDate"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblMeetingDate" runat="server" SkinID="lblskingen" Text='<%#Eval("MeetingDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="wb-col-action" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="MeetingTime">
                                        <HeaderTemplate>
                                            <asp:LinkButton ID="lnk5" runat="server" Text="MeetingTime" CommandName="Sort" CommandArgument="MeetingTime"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblMeetingTime" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("MeetingTime")) %>'></asp:Label> Hrs.
                                        </ItemTemplate>
                                        <ItemStyle CssClass="wb-col-action" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="AgendaSubmissionDate">
                                        <HeaderTemplate>
                                            <asp:LinkButton ID="lnk6" runat="server" Text="Agenda Submission Date" CommandName="Sort"
                                                CommandArgument="AgendaSubmissionDate"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblAgendaSubmissionDate" runat="server" SkinID="lblskingen" Text='<%#Eval("AgendaSubmissionDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="wb-col-action" />
                                    </asp:TemplateField>
                                    <asp:TemplateField>
                                        <ItemTemplate>
                                            <asp:Button ID="btnEdit" CssClass="wb-link-btn wb-link-edit" Text="Edit" ToolTip="Edit"
                                                CommandArgument='<%#Eval("MeetingId")%>' runat="server" CommandName="EditRec" />
                                        </ItemTemplate>
                                        <ItemStyle CssClass="wb-col-action" />
                                    </asp:TemplateField>
                                    <asp:TemplateField>
                                        <ItemTemplate>
                                            <asp:Button ID="btnDelete" CssClass="wb-link-btn wb-link-delete" Text="Delete" ToolTip="Delete"
                                                CommandArgument='<%#Eval("MeetingId")%>' runat="server" CommandName="DeleteRec"
                                                OnClientClick="return confirm('Are you sure you want to delete this Record?');" />
                                        </ItemTemplate>
                                        <ItemStyle CssClass="wb-col-action" />
                                    </asp:TemplateField>
                                </Columns>
                                <EmptyDataTemplate>
                                    <div class="divNoRecord">
                                        <%#Session["NoRecord"].ToString()%>
                                    </div>
                                </EmptyDataTemplate>
                            </asp:GridView>
                        </div>
                        <p class="wb-help">
                            Choose a committee to list its meetings. Click a column heading to sort. Delete asks
                            for confirmation; a meeting that is in use cannot be deleted.</p>
                    </div>
                </asp:Panel>
                <asp:Panel ID="pnlEditMeeting" runat="server">
                    <div class="wb-card">
                        <div class="wb-card-header">
                            Meeting details</div>
                        <div class="wb-card-body">
                            <div class="wb-row">
                                <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlCommittee">
                                    Committee Name</label>
                                <div class="wb-field">
                                    <asp:DropDownList ID="ddlCommittee" runat="server">
                                    </asp:DropDownList>
                                </div>
                            </div>
                            <div class="wb-row">
                                <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtMeetingNo">
                                    Meeting No</label>
                                <div class="wb-field">
                                    <asp:TextBox ID="txtMeetingNo" runat="server" MaxLength="6" ReadOnly="true"></asp:TextBox>
                                    <asp:HiddenField ID="hdnMeetingId" runat="server" />
                                </div>
                            </div>
                            <div class="wb-row">
                                <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtPlace">
                                    Place <span class="wb-req">*</span></label>
                                <div class="wb-field">
                                    <asp:TextBox ID="txtPlace" runat="server"></asp:TextBox>
                                </div>
                            </div>
                            <div class="wb-row">
                                <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtVenue">
                                    Venue <span class="wb-req">*</span></label>
                                <div class="wb-field">
                                    <asp:TextBox ID="txtVenue" runat="server" TextMode="MultiLine"></asp:TextBox>
                                </div>
                            </div>
                            <div class="wb-row">
                                <div class="wb-label">
                                    Meeting Date <span class="wb-req">*</span></div>
                                <div class="wb-field">
                                    <asp:HiddenField ID="hdnMeetingDate" runat="server" />
                                    <asp:TextBox ID="txtMeetingDate" runat="server" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                                    <asp:ImageButton runat="Server" ID="imgMeetingDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                    <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender2" runat="server"
                                        TargetControlID="txtMeetingDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                        PopupButtonID="imgMeetingDate">
                                    </cc1:CalendarExtender>
                                </div>
                            </div>
                            <div class="wb-row">
                                <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtMeetingTime">
                                    Meeting Time <span class="wb-req">*</span></label>
                                <div class="wb-field">
                                    <asp:TextBox ID="txtMeetingTime" CssClass="txtTimeFormat" runat="server"></asp:TextBox>
                                    <span class="wb-unit">Hrs.</span>
                                    <cc1:MaskedEditExtender ID="MaskedEditExtender1" runat="server" TargetControlID="txtMeetingTime"
                                        Mask="99:99" MaskType="Time" AcceptAMPM="false">
                                    </cc1:MaskedEditExtender>
                                </div>
                            </div>
                            <div class="wb-row">
                                <div class="wb-label">
                                    Agenda Submission Date <span class="wb-req">*</span></div>
                                <div class="wb-field">
                                    <asp:TextBox ID="txtAgendaSubmissionDate" runat="server" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                                    <asp:ImageButton runat="Server" ID="imgAgendaSubmissionDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                    <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender1" runat="server"
                                        TargetControlID="txtAgendaSubmissionDate" Animated="true" Format="dd-MMM-yyyy"
                                        PopupPosition="Right" PopupButtonID="imgAgendaSubmissionDate">
                                    </cc1:CalendarExtender>
                                </div>
                            </div>
                            <div class="wb-hidden">
                                MeetingColorCode :
                                <input id="txtColor" name="txtColor" runat="server" value="#FFFFFF" style="width: 80px;">
                                <input type="button" value="..." onclick="showColorPicker(this,ctl00_ContentPlaceHolder1_txtColor);	document.getElementById('ctl00_ContentPlaceHolder1_txtColor').style.backgroundColor = document.getElementById('ctl00_ContentPlaceHolder1_txtColor').value;">
                            </div>
                            <div class="wb-actions">
                                <asp:Button ID="btnSave" runat="server" CssClass="wb-btn" Text="Save" OnClick="btnSave_Click" />
                                <asp:Button ID="btnCancel" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Cancel"
                                    OnClick="btnCancel_Click" />
                            </div>
                        </div>
                    </div>
                </asp:Panel>
            </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
