<%@ Control Language="C#" AutoEventWireup="true" Codebehind="MeetingSummary.ascx.cs"
    Inherits="BMMS.UserControl.MeetingSummary" %>
<h2>
    Scheduled Meetings:</h2>
<div style="padding: 5px; margin-bottom: 10px; height:400px;">
    <table border="0" width="100%" cellspacing="0" cellpadding="0">
        <tr>
            <td valign="top">
                <asp:GridView ID="grvMeetSchedule" runat="server" CssClass="contentTable1"
                    CellPadding="3" CellSpacing="2" Width="100%" AutoGenerateColumns="False"
                    BorderStyle="None" BorderWidth="0px">
                    <HeaderStyle HorizontalAlign="Center" CssClass="contentTableHeader" Font-Bold="True" />
                    <RowStyle CssClass="contentTabletd" borderstyle="Solid" borderwidth="0px" />
                    <AlternatingRowStyle borderstyle="Solid" borderwidth="0px" />
                    <FooterStyle CssClass="contentTabletd" />
                    <SelectedRowStyle CssClass="bmms-row-selected" font-bold="True" />
                    <PagerStyle HorizontalAlign="Center" />
                    <Columns>
                        <asp:TemplateField HeaderText="Committee">
                            <ItemTemplate>
                                <asp:Label ID="lblCommitteeName" runat="server" Text='<%#Eval("CommitteeName") %>'></asp:Label>
                            </ItemTemplate>
                            <ItemStyle VerticalAlign="Middle" HorizontalAlign="Left" />
                        </asp:TemplateField>
                        <asp:TemplateField HeaderText="Meeting No">
                            <ItemTemplate>
                                <asp:Label ID="lblMeetingNo" runat="server" Text='<%#Eval("MeetingNo") %>'></asp:Label>
                                <asp:Label ID="lblMeetingId" runat="server" Text='<%#Eval("MeetingId") %>' Visible="false"></asp:Label>
                            </ItemTemplate>
                            <ItemStyle VerticalAlign="Middle" HorizontalAlign="Center" />
                        </asp:TemplateField>
                        <asp:TemplateField HeaderText="Meeting <br/>Date">
                            <ItemTemplate>
                                <asp:Label ID="lblMeetingDate" runat="server" Text='<%#Eval("MeetingDate", "{0:dd-MMM-yyyy}") %>'></asp:Label>
                                <asp:Label ID="lblMeetingTime" runat="server" Text='<%#Eval("MeetingTime") %>'></asp:Label> Hrs.
                            </ItemTemplate>
                            <ItemStyle VerticalAlign="Middle" HorizontalAlign="Center" />
                        </asp:TemplateField>
                    </Columns>
                </asp:GridView>
            </td>
        </tr>
    </table>
</div>

<div style="padding: 5px; margin-bottom: 10px; visibility:hidden; height:0px;">
<h2>
    Completed Meetings:</h2>
    <table border="0" width="100%" cellspacing="0" cellpadding="0" class="leftColTab">
        <tr>
            <td valign="Top">
            <asp:GridView ID="grvCompleteMeet" runat="server" CssClass="contentTable1"
                    CellPadding="3" CellSpacing="2" Width="100%" AutoGenerateColumns="False"
                    BorderStyle="None" BorderWidth="0px">
                    <HeaderStyle HorizontalAlign="Center" CssClass="contentTableHeader" Font-Bold="True" />
                    <RowStyle CssClass="contentTabletd" borderstyle="Solid" borderwidth="0px" />
                    <AlternatingRowStyle borderstyle="Solid" borderwidth="0px" />
                    <FooterStyle CssClass="contentTabletd" />
                    <SelectedRowStyle CssClass="bmms-row-selected" font-bold="True" />
                    <PagerStyle HorizontalAlign="Center" />
                    <Columns>
                        <asp:TemplateField HeaderText="Committee">
                            <ItemTemplate>
                                <asp:Label ID="lblCommitteeName" runat="server" Text='<%#Eval("CommitteeName") %>'></asp:Label>
                            </ItemTemplate>
                            <ItemStyle VerticalAlign="Middle" HorizontalAlign="Left" />
                        </asp:TemplateField>
                        <asp:TemplateField HeaderText="Meeting No">
                            <ItemTemplate>
                                <asp:Label ID="lblMeetingNo" runat="server" Text='<%#Eval("MeetingNo") %>'></asp:Label>
                                <asp:Label ID="lblMeetingId" runat="server" Text='<%#Eval("MeetingId") %>' Visible="false"></asp:Label>
                            </ItemTemplate>
                            <ItemStyle VerticalAlign="Middle" HorizontalAlign="Center" />
                        </asp:TemplateField>
                        <asp:TemplateField HeaderText="Meeting <br/>Date">
                            <ItemTemplate>
                                <asp:Label ID="lblMeetingDate" runat="server" Text='<%#Eval("MeetingDate", "{0:dd-MMM-yyyy}") %>'></asp:Label>
                                <asp:Label ID="lblMeetingTime" runat="server" Text='<%#Eval("MeetingTime") %>'></asp:Label> Hrs.
                            </ItemTemplate>
                            <ItemStyle VerticalAlign="Middle" HorizontalAlign="Center" />
                        </asp:TemplateField>
                    </Columns>
                </asp:GridView>
            </td>
        </tr>
    </table>
</div>
