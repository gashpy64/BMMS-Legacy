<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="Meeting.aspx.cs" Inherits="BMMS.Master.Meeting" Title="Untitled Page" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <link rel="stylesheet" href="../JScript/ColorPicker/js_color_picker_v2.css" media="screen">

    <script src="../JScript/ColorPicker/color_functions.js"></script>

    <script type="text/javascript" src="../JScript/ColorPicker/js_color_picker_v2.js"></script>

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
            <div class="formContent">
            <div class="formPanel">
            <div class="divHeader">
                :: Meeting Master</div>
                <div class="divRowFixed">
                </div>
                <div class="divRow" style="height: 25px">
                    <div id="divErrLogin" runat="server" class="divErrorHide">
                        <span id="spanErrLogin" runat="server" class="lblError"></span>
                    </div>
                </div>
                <asp:Panel ID="pnlViewMeeting" runat="server">
                    <div class="divRow" style="margin: auto; float: none; width: 900px;">
                    <div class="divRow">
                        <div class="divRow">
                            <div class="divRowLeft">
                                Committee Name :
                            </div>
                            <div class="divRowRight">
                                <asp:DropDownList ID="ddlCommitteeSearch" runat="server" Width="150px" AutoPostBack="true"
                                    OnSelectedIndexChanged="ddlCommitteeSearch_SelectedIndexChanged">
                                </asp:DropDownList>
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <asp:Button ID="btnAdd" runat="server" CssClass="button" Text="Add" OnClick="btnAdd_Click" />
                    </div>
                    <div class="divRowGridScroll">
                        <asp:GridView ID="grvMeeting" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                            CssClass="contentTable1" AllowSorting="true" CellPadding="4" DataKeyNames="MeetingId"
                            Font-Names="Verdana, Arial, Helvetica, sans-serif" Font-Size="X-Small" ForeColor="#333333"
                            GridLines="Horizontal" Height="32px" Width="100%" OnRowDataBound="grvMeeting_RowDataBound"
                            OnSorting="grvRecord_Sorting" OnRowCommand="grvMeeting_RowCommand">
                            <HeaderStyle CssClass="contentTableHeader" HorizontalAlign="Center" Font-Bold="true" />
                            <Columns>
                                <asp:TemplateField HeaderText="S.No.">
                                    <ItemTemplate>
                                        <%# Container.DataItemIndex+1 + "."%>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                        Width="10px" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="MeetingNo">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="lnk1" runat="server" Text="Meeting No" CommandName="Sort" Style="color: White"
                                            CommandArgument="MeetingNo"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblMeetingNoe" SkinID="lblSkinGen" Text='<%#Eval("MeetingNo")%>' runat="server" />
                                        <asp:HiddenField ID="hdnMeetingNo" runat="server" />
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="CommitteeName">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="lnk2" runat="server" Text="Committee Name" CommandName="Sort"
                                            Style="color: White" CommandArgument="CommitteeName"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblCommitteeName" runat="server" SkinID="lblskingen" Text='<%#Eval("CommitteeName")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="Place">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="lnk3" runat="server" Text="Place" CommandName="Sort" Style="color: White"
                                            CommandArgument="Place"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblPlace" runat="server" SkinID="lblskingen" Text='<%#Eval("Place")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="Venue">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="lnk3" runat="server" Text="Venue" CommandName="Sort" Style="color: White"
                                            CommandArgument="Venue"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblVenue" runat="server" SkinID="lblskingen" Text='<%#Eval("Venue")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="MeetingDate">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="lnk4" runat="server" Text="Meeting Date" CommandName="Sort" Style="color: White"
                                            CommandArgument="MeetingDate"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblMeetingDate" runat="server" SkinID="lblskingen" Text='<%#Eval("MeetingDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" Width="100px" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="MeetingTime">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="lnk5" runat="server" Text="MeetingTime" CommandName="Sort" Style="color: White"
                                            CommandArgument="MeetingTime"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblMeetingTime" runat="server" SkinID="lblskingen" Text='<%#Eval("MeetingTime")%>'></asp:Label> Hrs.
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" Width="100px" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="AgendaSubmissionDate">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="lnk6" runat="server" Text="Agenda Submission Date" CommandName="Sort" Style="color: White"
                                            CommandArgument="AgendaSubmissionDate"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblAgendaSubmissionDate" runat="server" SkinID="lblskingen" Text='<%#Eval("AgendaSubmissionDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" Width="100px" />
                                </asp:TemplateField>
                                <asp:TemplateField>
                                    <ItemTemplate>
                                        <asp:Button ID="btnEdit" Width="18px" Height="18px" CssClass="buttonEdit" ToolTip="Edit"
                                            CommandArgument='<%#Eval("MeetingId")%>' runat="server" CommandName="EditRec" />
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                        Width="30px" />
                                </asp:TemplateField>
                                <asp:TemplateField>
                                    <ItemTemplate>
                                        <asp:Button ID="btnDelete" Width="18px" Height="18px" CssClass="buttonDelete" ToolTip="Delete"
                                            CommandArgument='<%#Eval("MeetingId")%>' runat="server" CommandName="DeleteRec"
                                            OnClientClick="return confirm('Are you sure you want to delete this Record?');" />
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                        Width="30px" />
                                </asp:TemplateField>
                            </Columns>
                            <EmptyDataTemplate>
                                <div class="divNoRecord">
                                    <%#Session["NoRecord"].ToString()%>
                                </div>
                            </EmptyDataTemplate>
                        </asp:GridView>
                    </div>
                    </div>
                </asp:Panel>
                <asp:Panel ID="pnlEditMeeting" runat="server">
                    <div class="divRow">
                        <div class="divRow">
                            <div class="divRow">
                                <div class="divRowLeft">
                                    Committee Name :
                                </div>
                                <div class="divRowRight">
                                    <asp:DropDownList ID="ddlCommittee" runat="server" Width="150px">
                                    </asp:DropDownList>
                                </div>
                            </div>
                        </div>
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
                                    Place :
                                </div>
                                <div class="divRowRight">
                                    <asp:TextBox ID="txtPlace" runat="server"></asp:TextBox>
                                    <span class="spanMandatory">*</span>
                                </div>
                            </div>
                        </div>
                        <div class="divRow">
                            <div class="divRow">
                                <div class="divRowLeft">
                                    Venue :
                                </div>
                                <div class="divRowRight">
                                    <div style="float: left;">
                                        <asp:TextBox ID="txtVenue" runat="server" TextMode="MultiLine" Height="70px"></asp:TextBox>
                                    </div>
                                    <div style="float: left;">
                                        <span class="spanMandatory">*</span>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div class="divRow">
                            <div class="divRow">
                                <div class="divRowLeft">
                                    Meeting Date :
                                </div>
                                <div class="divRowRight">
                                    <asp:HiddenField ID="hdnMeetingDate" runat="server" />
                                    <asp:TextBox ID="txtMeetingDate" runat="server" Width="100px" onfocus="this.blur();"
                                        TabIndex="-1"></asp:TextBox>
                                    <asp:ImageButton runat="Server" ID="imgMeetingDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                    <span class="spanMandatory">*</span>
                                    <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender2" runat="server"
                                        TargetControlID="txtMeetingDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                        PopupButtonID="imgMeetingDate">
                                    </cc1:CalendarExtender>
                                </div>
                            </div>
                        </div>
                        <div class="divRow">
                            <div class="divRow">
                                <div class="divRowLeft">
                                    Meeting Time :
                                </div>
                                <div class="divRowRight">
                                    <asp:TextBox ID="txtMeetingTime" CssClass="txtTimeFormat" runat="server"></asp:TextBox> Hrs.
                                    <span class="spanMandatory">*</span>
                                    <cc1:MaskedEditExtender ID="MaskedEditExtender1" runat="server" TargetControlID="txtMeetingTime"
                                        Mask="99:99" MaskType="Time" AcceptAMPM="false">
                                    </cc1:MaskedEditExtender>
                                </div>
                            </div>
                            <div class="divRow">
                                <div class="divRow">
                                    <div class="divRowLeft">
                                        Agenda Submission Date :
                                    </div>
                                    <div class="divRowRight">
                                        <asp:TextBox ID="txtAgendaSubmissionDate" runat="server" Width="100px" onfocus="this.blur();"
                                            TabIndex="-1"></asp:TextBox>
                                        <asp:ImageButton runat="Server" ID="imgAgendaSubmissionDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                        <span class="spanMandatory">*</span>
                                        <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender1" runat="server"
                                            TargetControlID="txtAgendaSubmissionDate" Animated="true" Format="dd-MMM-yyyy"
                                            PopupPosition="Right" PopupButtonID="imgAgendaSubmissionDate">
                                        </cc1:CalendarExtender>
                                    </div>
                                </div>
                            </div>
                            <div class="divRow" style="visibility: hidden; height: 0px;">
                                <div class="divRow">
                                    <div class="divRowLeft">
                                        MeetingColorCode :
                                    </div>
                                    <div class="divRowRight">
                                        <input id="txtColor" name="txtColor" runat="server" value="#FFFFFF" style="width: 80px;">
                                        <input type="button" value="..." onclick="showColorPicker(this,ctl00_ContentPlaceHolder1_txtColor);	document.getElementById('ctl00_ContentPlaceHolder1_txtColor').style.backgroundColor = document.getElementById('ctl00_ContentPlaceHolder1_txtColor').value;">
                                    </div>
                                </div>
                            </div>
                            <div class="divRow">
                                <div class="divRow">
                                    <div class="divRowLeft">
                                        <span class="spanWhite">.</span>
                                    </div>
                                    <div class="divRowRight">
                                        <asp:Button ID="btnSave" runat="server" CssClass="button" Text="Save" OnClick="btnSave_Click" />
                                        <asp:Button ID="btnCancel" runat="server" CssClass="button" Text="Cancel" OnClick="btnCancel_Click" />
                                    </div>
                                </div>
                            </div>
                        </div>
                </asp:Panel>
            </div>
            </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
