<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="AgendaApproval.aspx.cs" Inherits="BMMS.Report.AgendaApproval" Title="Agenda Approval" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <asp:Panel ID="pnlMeetingMaster" runat="server">
                <div class="formContent">
                <div class="formPanel">
                    <div class="divHeader">
                    :: Agenda Approval / Reject Report</div>
                    <div class="divRowFixed"></div>
                    <div class="divRow">
                    <table border="0" cellpadding="0" cellspacing="12" width="100%">
                        <tr>
                            <td class="Lable" width="30%">
                                Committee :</td>
                            <td>
                                <asp:DropDownList ID="ddlCommittee" runat="server" Width="150px" AutoPostBack="true"
                                    OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                                </asp:DropDownList>&nbsp;
                            </td>
                        </tr>
                        <tr>
                            <td class="Lable" width="30%">
                                Meeting No :</td>
                            <td>
                                <asp:DropDownList ID="ddlMeeting" runat="server" Width="150px" AutoPostBack="true"
                                    OnSelectedIndexChanged="ddlMeeting_SelectedIndexChanged">
                                </asp:DropDownList></td>
                        </tr>
                        <tr>
                            <td class="Lable" width="30%">
                                View Format :</td>
                            <td>
                                <asp:RadioButtonList ID="rdoViewFormat" runat="server" AutoPostBack="True" OnSelectedIndexChanged="rdoViewFormat_SelectedIndexChanged"
                                    RepeatDirection="Horizontal">
                                    <asp:ListItem Text="View" Value="View" Selected="True"></asp:ListItem>
                                    <%--<asp:ListItem Text="Print" Value="Print"></asp:ListItem>--%>
                                </asp:RadioButtonList>
                            </td>
                        </tr>
                    </table>
                    </div>
                    <asp:Panel ID="pnlPrintReport" runat="server" Visible="false">
                        <table border="0" cellpadding="0" cellspacing="12" width="100%">
                            <tr>
                                <td class="Lable" width="30%">
                                    Meeting Venue :</td>
                                <td>
                                    <asp:TextBox ID="txtMeetingVenue" runat="server" TextMode="MultiLine" Height="50px" ></asp:TextBox>
                                </td>
                            </tr>
                            <tr>
                                <td class="Lable" width="30%">
                                    Meeting Date :</td>
                                <td>
                                    <asp:TextBox ID="txtMeetingDate" runat="server"></asp:TextBox>
                                </td>
                            </tr>
                            <tr>
                                <td class="Lable" width="30%">
                                    Meeting Time :</td>
                                <td>
                                    <asp:TextBox ID="txtMeetingTime" CssClass="txtTimeFormat" runat="server"></asp:TextBox> Hrs.
                                </td>
                            </tr>
                            <tr>
                                <td>
                                    &nbsp;</td>
                                <td>
                                    <asp:Button ID="btnCreatePDF" runat="server" Text="Create PDF" OnClick="btnCreatePDF_Click"
                                        CssClass="button" />
                                </td>
                            </tr>
                            <tr>
                                <td>
                                    &nbsp;</td>
                                <td>
                                    <asp:Panel ID="pnlAgendaDetailsDownload" runat="server" Visible="false">
                                        <a href="../Files/PDF/AgendaApproval.pdf" target="_blank">Download Agenda Details</a>
                                    </asp:Panel>
                                </td>
                            </tr>
                        </table>
                    </asp:Panel>
                    
                    <asp:Panel ID="pnlViewReport" runat="server">
                        <div class="divRow">
                            <asp:GridView ID="grvAgendaDetails" runat="server" AutoGenerateColumns="false"
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
                                    <asp:TemplateField SortExpression="MeetingNo">
                                        <HeaderTemplate>
                                            <asp:LinkButton runat="server" Text="Meeting No" CommandName="Sort"
                                                Style="color: White" CommandArgument="MeetingNo"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblMeetingNoe" SkinID="lblSkinGen" Text='<%#Eval("MeetingNo")%>' runat="server" />
                                            <asp:HiddenField ID="hdnMeetingNo" runat="server" />
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="MeetingDate">
                                        <HeaderTemplate>
                                            <asp:LinkButton runat="server" Text="Meeting Date / Time" CommandName="Sort"
                                                Style="color: White" CommandArgument="MeetingDate"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblMeetingDate" runat="server" SkinID="lblskingen" Text='<%#Eval("MeetingDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                            &nbsp; / &nbsp; 
                                            <asp:Label ID="lblMeetingTime" runat="server" SkinID="lblskingen" Text='<%#Eval("MeetingTime")%>'></asp:Label> Hrs.
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="AgendaNo">
                                        <HeaderTemplate>
                                            <asp:LinkButton runat="server" Text="Agenda No" CommandName="Sort"
                                                Style="color: White" CommandArgument="AgendaNo"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblAgendaNo" runat="server" SkinID="lblskingen" Text='<%#Eval("AgendaNo")%>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="SubjectNo">
                                        <HeaderTemplate>
                                            <asp:LinkButton runat="server" Text="Subject No" CommandName="Sort" Style="color: White"
                                                CommandArgument="SubjectNo"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblSubjectNo" runat="server" SkinID="lblskingen" Text='<%#Eval("SubjectNo")%>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="DepartmentName">
                                        <HeaderTemplate>
                                            <asp:LinkButton runat="server" CommandArgument="DepartmentName" CommandName="Sort"
                                                Style="color: White" Text="Department"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblDepartmentName" runat="server" SkinID="lblskingen" Text='<%#Eval("DepartmentName")%>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" HorizontalAlign="Left" VerticalAlign="Middle" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="AgendaStatusName">
                                        <HeaderTemplate>
                                            <asp:LinkButton ID="lnkAgendaStatusName" runat="server" CommandArgument="AgendaStatusName"
                                                CommandName="Sort" Style="color: White" Text="Agenda Status"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblAgendaStatusName" runat="server" SkinID="lblskingen" Text='<%#Eval("AgendaStatusName")%>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" HorizontalAlign="Left" VerticalAlign="Middle" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="ShortText">
                                        <HeaderTemplate>
                                            <asp:LinkButton runat="server" CommandArgument="ShortText" CommandName="Sort"
                                                Style="color: White" Text="Agenda Short Text"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblShortText" runat="server" SkinID="lblskingen" Text='<%#Eval("ShortText")%>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" HorizontalAlign="Left" VerticalAlign="Middle" />
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
            </asp:Panel>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
