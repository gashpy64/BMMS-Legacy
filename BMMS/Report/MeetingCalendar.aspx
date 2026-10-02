<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="MeetingCalendar.aspx.cs" Inherits="BMMS.Report.MeetingCalendar" Title="Meeting Calendar" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <asp:Panel ID="pnlCommitteeMaster" runat="server">
                <div class="formContent">
                <div class="formPanel">
                    <div class="divHeader">
                    :: Meeting Calendar Report</div>
                    <div class="divRowFixed"></div>
                    <div class="divRow">
                        <div class="divRow">
                            <div class="divRowLeft">
                                From Date :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtFromDate" runat="server" Width="100px" onfocus="this.blur();"
                                    TabIndex="-1"></asp:TextBox>
                                <asp:ImageButton runat="Server" ID="imgFromDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                <span class="spanMandatory">*</span>
                                <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender2" runat="server" TargetControlID="txtFromDate"
                                    Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right" PopupButtonID="imgFromDate">
                                </cc1:CalendarExtender>
                            </div>
                        </div>
                        <div class="divRow">
                            <div class="divRowLeft">
                                To Date :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtToDate" runat="server" Width="100px" onfocus="this.blur();" 
                                    TabIndex="-1"></asp:TextBox>
                                <asp:ImageButton runat="Server" ID="imgToDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender1" runat="server" TargetControlID="txtToDate"
                                    Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right" PopupButtonID="imgToDate">
                                </cc1:CalendarExtender>
                            </div>
                        </div>
                        <div class="divRow">
                            <div class="divRowLeft">
                                Sort Option :
                            </div>
                            <div class="divRowRight">
                                <asp:RadioButtonList ID="rdoSortOption" runat="server" AutoPostBack="True"
                                    RepeatDirection="Horizontal">
                                    <asp:ListItem Text="Committee" Value="Committee" Selected="True"></asp:ListItem>
                                    <asp:ListItem Text="Meeting Date" Value="MeetingDate"></asp:ListItem>
                                </asp:RadioButtonList>
                                <br />
                                <br />
                                <asp:Button ID="btnSubmit" runat="server" CssClass="button" Text="Submit" OnClick="btnSubmit_Click" />
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <asp:GridView ID="grvMeetingCalendar" runat="server" AutoGenerateColumns="false"
                            CssClass="contentTable1" AllowSorting="true" CellPadding="4" DataKeyNames="MeetingId"
                            Font-Names="Verdana, Arial, Helvetica, sans-serif" Font-Size="X-Small" ForeColor="#333333"
                            GridLines="Horizontal" Height="32px" Width="100%" OnSorting="grvRecord_Sorting">
                            <HeaderStyle CssClass="contentTableHeader" HorizontalAlign="Center" Font-Bold="true" />
                            <Columns>
                                <asp:TemplateField HeaderText="S.No.">
                                    <ItemTemplate>
                                        <%# Container.DataItemIndex+1 + "."%>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                        Width="10px" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="CommitteeName">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Committee Name" CommandName="Sort" Style="color: White"
                                            CommandArgument="CommitteeName"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblCommitteeName" runat="server" SkinID="lblskingen" Text='<%#Eval("CommitteeName")%>'></asp:Label>
                                        (<asp:Label ID="lblCommitteeCode" runat="server" SkinID="lblskingen" Text='<%#Eval("CommitteeCode")%>'></asp:Label>)
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="MeetingNo">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Meeting No" CommandName="Sort" Style="color: White"
                                            CommandArgument="MeetingNo"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblMeetingNoe" SkinID="lblSkinGen" Text='<%#Eval("MeetingNo")%>' runat="server" />
                                        <asp:HiddenField ID="hdnMeetingNo" runat="server" />
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="MeetingDate">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Meeting Date" CommandName="Sort" Style="color: White"
                                            CommandArgument="MeetingDate"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblMeetingDate" runat="server" SkinID="lblskingen" Text='<%#Eval("MeetingDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="MeetingTime">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="MeetingTime" CommandName="Sort" Style="color: White"
                                            CommandArgument="MeetingTime"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblMeetingTime" runat="server" SkinID="lblskingen" Text='<%#Eval("MeetingTime")%>'></asp:Label> Hrs.
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="Venue">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Venue" CommandName="Sort" Style="color: White"
                                            CommandArgument="Venue"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblVenue" runat="server" SkinID="lblskingen" Text='<%#Eval("Venue")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
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
                </div>
            </asp:Panel>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
