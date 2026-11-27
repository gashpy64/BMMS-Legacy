<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="AttendanceDetails.aspx.cs" Inherits="BMMS.Report.AttendanceDetails"
    Title="Attendance Details" ValidateRequest="false" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <%-- Step UI2b: the Masters' form look (Committee Master): breadcrumb and title as in the menu, a card with label
         and field rows. The attendance list stays outside .wb-page in its old frame (R12). Control IDs, events
         and the handlers are unchanged. --%>
    <div class="wb-page wb-page-fit">
        <div class="wb-breadcrumb">
            Reports<span class="wb-breadcrumb-sep">/</span>Attendance Details</div>
        <h1 class="wb-h1">
            Attendance Details</h1>
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
                        Committee Name <span class="wb-req">*</span></label>
                    <div class="wb-field">
                        <asp:DropDownList ID="ddlCommittee" runat="server" AutoPostBack="true"
                            OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                        </asp:DropDownList>
                    </div>
                </div>
                <div class="wb-row">
                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlMeeting">
                        Meeting No <span class="wb-req">*</span></label>
                    <div class="wb-field">
                        <asp:DropDownList ID="ddlMeeting" runat="server" AutoPostBack="true"
                            OnSelectedIndexChanged="ddlMeeting_SelectedIndexChanged">
                        </asp:DropDownList>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <asp:Panel ID="pnlAttendance" runat="server">
        <%-- Step UI2b (R12): the list keeps its frame and look; the frame is inside the panel --%>
        <div class="formContent">
            <div class="formPanel">
                <div class="divRow">
                        <asp:GridView ID="grvAttendanceMember" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                            CssClass="contentTable1" AllowSorting="true" CellPadding="4" 
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
                                        <asp:LinkButton ID="LinkButton1" runat="server" Text="Committee Name" CommandName="Sort"
                                            Style="color: White" CommandArgument="CommitteeName"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblCommitteeName" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("CommitteeName")) %>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="MeetingNo">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="LinkButton2" runat="server" Text="Meeting No" CommandName="Sort"
                                            Style="color: White" CommandArgument="MeetingNo"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblMeetingNo" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("MeetingNo")) %>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="MeetingDate">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="LinkButton5" runat="server" Text="Meeting Date" CommandName="Sort"
                                            Style="color: White" CommandArgument="MeetingDate"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblMeetingDate" runat="server" SkinID="lblskingen" Text='<%#Eval("MeetingDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="MemberName">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="LinkButton3" runat="server" Text="Member Name" CommandName="Sort"
                                            Style="color: White" CommandArgument="MemberName"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblMemberName" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("MemberName")) %>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="DesignationName">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="LinkButton4" runat="server" Text="Designation" CommandName="Sort"
                                            Style="color: White" CommandArgument="DesignationName"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblDesignationName" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("DesignationName")) %>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="Attendance">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="LinkButton6" runat="server" Text="Attendance" CommandName="Sort"
                                            Style="color: White" CommandArgument="Attendance"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblAttendance" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("Attendance")) %>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
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
</asp:Content>
