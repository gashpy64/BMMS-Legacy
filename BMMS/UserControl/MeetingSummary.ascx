<%@ Control Language="C#" AutoEventWireup="true" Codebehind="MeetingSummary.ascx.cs"
    Inherits="BMMS.UserControl.MeetingSummary" %>
<h2>
    Scheduled Meetings:</h2>
<div style="padding: 5px; margin-bottom: 10px; height:400px;">
    <table border="0" width="100%" cellspacing="0" cellpadding="0">
        <tr>
            <td valign="top">
                <asp:GridView ID="grvMeetSchedule" runat="server" BackColor="white" HeaderStyle-BackColor=""
                    CellPadding="3" CellSpacing="2" Width="100%" AutoGenerateColumns="False" BorderColor="#DEBA84"
                    BorderStyle="None" BorderWidth="0px">
                    <HeaderStyle HorizontalAlign="Center" BackColor="#F3B876" Font-Bold="True" ForeColor="black" />
                    <RowStyle bordercolor="Gray" borderstyle="Solid" borderwidth="0px" backcolor="#FFF7E7"
                        forecolor="#8C4510" />
                    <AlternatingRowStyle bordercolor="Gray" borderstyle="Solid" borderwidth="0px" />
                    <FooterStyle BackColor="#F7DFB5" ForeColor="#8C4510" />
                    <SelectedRowStyle backcolor="#738A9C" font-bold="True" forecolor="White" />
                    <PagerStyle ForeColor="#8C4510" HorizontalAlign="Center" />
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
            <asp:GridView ID="grvCompleteMeet" runat="server" BackColor="white" HeaderStyle-BackColor=""
                    CellPadding="3" CellSpacing="2" Width="100%" AutoGenerateColumns="False" BorderColor="#DEBA84"
                    BorderStyle="None" BorderWidth="0px">
                    <HeaderStyle HorizontalAlign="Center" BackColor="#F3B876" Font-Bold="True" ForeColor="black" />
                    <RowStyle bordercolor="Gray" borderstyle="Solid" borderwidth="0px" backcolor="#FFF7E7"
                        forecolor="#8C4510" />
                    <AlternatingRowStyle bordercolor="Gray" borderstyle="Solid" borderwidth="0px" />
                    <FooterStyle BackColor="#F7DFB5" ForeColor="#8C4510" />
                    <SelectedRowStyle backcolor="#738A9C" font-bold="True" forecolor="White" />
                    <PagerStyle ForeColor="#8C4510" HorizontalAlign="Center" />
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
