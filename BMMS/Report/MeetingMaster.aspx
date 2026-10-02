<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="MeetingMaster.aspx.cs" Inherits="BMMS.Report.MeetingMaster" Title="Untitled Page" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <asp:Panel ID="pnlCommitteeMaster" runat="server">
                <div class="formContent">
                <div class="formPanel">
                    <div class="divHeader">
                    :: Meeting Master Report</div>
                    <div class="divRowFixed"></div>
                    <div class="divRow">
                        <table border="0" cellpadding="0" cellspacing="12" width="100%">
                            <tr>
                                <td class="Lable">
                                    Committee :</td>
                                <td>
                                    <asp:DropDownList ID="ddlCommittee" runat="server" Width="150px" AutoPostBack="true"
                                        OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                                    </asp:DropDownList>&nbsp;
                                </td>
                            </tr>
                            <tr>
                                <td class="Lable">
                                </td>
                                <td>
                                    <asp:Button ID="btnSubmit" runat="server" CssClass="button" Text="Submit" OnClick="btnSubmit_Click" /></td>
                            </tr>
                        </table>
                    </div>
                    <div class="divRow">
                        <asp:GridView ID="grvMeeting" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
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
                                        <asp:LinkButton runat="server" Text="Committee Name" CommandName="Sort"
                                            Style="color: White" CommandArgument="CommitteeName"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblCommitteeName" runat="server" SkinID="lblskingen" Text='<%#Eval("CommitteeName")%>'></asp:Label>
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
                                <asp:TemplateField SortExpression="MeetingTime">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Agenda Submission Date" CommandName="Sort"
                                            Style="color: White" CommandArgument="AgendaSubmissionDate"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblAgendaSubmissionDate" runat="server" SkinID="lblskingen" Text='<%#Eval("AgendaSubmissionDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
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
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
