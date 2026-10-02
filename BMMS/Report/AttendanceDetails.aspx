<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="AttendanceDetails.aspx.cs" Inherits="BMMS.Report.AttendanceDetails"
    Title="Attendance Details" ValidateRequest="false" %>

<%@ Register Assembly="FreeTextBox" Namespace="FreeTextBoxControls" TagPrefix="FTB" %>
<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="formContent">
    <div class="formPanel">
        <div class="divHeader">
        :: Attendance</div>
        <div class="divRowFixed">
        </div>
        <div class="divRow" style="height: 25px">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
        </div>
        <div class="divRow">
            <div class="divRow">
                <div class="divRowLeft">
                    Committee Name :
                </div>
                <div class="divRowRight">
                    <asp:DropDownList ID="ddlCommittee" runat="server" Width="150px" AutoPostBack="true"
                        OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                    </asp:DropDownList>
                    <span class="spanMandatory">*</span>
                </div>
            </div>
            <div class="divRow">
                <div class="divRowLeft">
                    Meeting No :
                </div>
                <div class="divRowRight">
                    <asp:DropDownList ID="ddlMeeting" runat="server" Width="150px" AutoPostBack="true"
                        OnSelectedIndexChanged="ddlMeeting_SelectedIndexChanged">
                    </asp:DropDownList>
                    <span class="spanMandatory">*</span>
                    <br />
                </div>
            </div>
            <div class="divRow">
                <asp:Panel ID="pnlAttendance" runat="server">
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
                                        <asp:Label ID="lblCommitteeName" runat="server" SkinID="lblskingen" Text='<%#Eval("CommitteeName")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="MeetingNo">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="LinkButton1" runat="server" Text="Meeting No" CommandName="Sort"
                                            Style="color: White" CommandArgument="MeetingNo"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblMeetingNo" runat="server" SkinID="lblskingen" Text='<%#Eval("MeetingNo")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="MeetingDate">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="LinkButton1" runat="server" Text="Meeting Date" CommandName="Sort"
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
                                        <asp:Label ID="lblMemberName" runat="server" SkinID="lblskingen" Text='<%#Eval("MemberName")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="DesignationName">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="LinkButton4" runat="server" Text="Designation" CommandName="Sort"
                                            Style="color: White" CommandArgument="DesignationName"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblDesignationName" runat="server" SkinID="lblskingen" Text='<%#Eval("DesignationName")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="Attendance">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="LinkButton4" runat="server" Text="Attendance" CommandName="Sort"
                                            Style="color: White" CommandArgument="Attendance"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblAttendance" runat="server" SkinID="lblskingen" Text='<%#Eval("Attendance")%>'></asp:Label>
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
                </asp:Panel>
            </div>
        </div>
    </div>
    </div>
</asp:Content>
