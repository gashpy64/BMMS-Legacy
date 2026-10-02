<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="Reports.aspx.cs" Inherits="BMMS.Report.Reports" Title="Untitled Page" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
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
            <asp:Panel ID="pnlMeetingMaster" runat="server">
                <div class="formContent">
                    <div class="formPanel">
                        <div class="divHeader">
                            <asp:Label ID="lblPageHeader" runat="server" Text=""></asp:Label></div>
                        <div class="divRowFixed" style="height: 500px;">
                        </div>
                        <div class="divRow" style="height: 25px">
                            <div id="divErrLogin" runat="server" class="divErrorHide">
                                <span id="spanErrLogin" runat="server" class="lblError"></span>
                            </div>
                        </div>
                        <asp:Panel ID="pnlReportFilter" runat="server">
                            <div class="divRow">
                                <table cellspacing="12" cellpadding="0" border="0" width="100%">
                                    <tr>
                                        <td class="Lable" style="width: 40%">
                                            Committee Name :
                                        </td>
                                        <td>
                                            <asp:DropDownList ID="ddlCommittee" runat="server" Width="300px" AutoPostBack="true"
                                                OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                                            </asp:DropDownList>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td class="Lable">
                                            Department :
                                        </td>
                                        <td>
                                            <asp:DropDownList ID="ddlDepartment" runat="server" Width="300px" AutoPostBack="true"
                                                OnSelectedIndexChanged="ddlDepartment_SelectedIndexChanged">
                                            </asp:DropDownList>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td class="Lable">
                                            Meeting No. :
                                        </td>
                                        <td>
                                            <asp:RadioButtonList ID="rdoMeatingNoSearch" runat="server" RepeatDirection="Horizontal"
                                                AutoPostBack="true" OnSelectedIndexChanged="rdoMeatingNoSearch_SelectedIndexChanged">
                                                <asp:ListItem Text="Particular" Value="0" Selected="True"></asp:ListItem>
                                                <asp:ListItem Text="Between" Value="1"></asp:ListItem>
                                            </asp:RadioButtonList>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td class="Lable">
                                        </td>
                                        <td>
                                            <asp:Panel ID="pnlMeetingNoParticular" runat="server">
                                                <asp:DropDownList ID="ddlMeetingNo" runat="server" Width="80px" AutoPostBack="true"
                                                    OnSelectedIndexChanged="ddlMeetingNo_SelectedIndexChanged">
                                                </asp:DropDownList>
                                            </asp:Panel>
                                            <asp:Panel ID="pnlMeetingNoBetween" runat="server">
                                                <asp:DropDownList ID="ddlMeetingNoFrom" runat="server" Width="80px">
                                                </asp:DropDownList>
                                                <asp:Label ID="Label1" runat="server" Text=" to "></asp:Label>
                                                <asp:DropDownList ID="ddlMeetingNoTo" runat="server" Width="80px">
                                                </asp:DropDownList>
                                            </asp:Panel>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td class="Lable">
                                            Subject No. :
                                        </td>
                                        <td>
                                            <asp:RadioButtonList ID="rdoSubjectNoSearch" runat="server" RepeatDirection="Horizontal"
                                                AutoPostBack="true" OnSelectedIndexChanged="rdoSubjectNoSearch_SelectedIndexChanged">
                                                <asp:ListItem Text="All" Value="0" Selected="True"></asp:ListItem>
                                                <asp:ListItem Text="Between" Value="1"></asp:ListItem>
                                            </asp:RadioButtonList>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td class="Lable">
                                        </td>
                                        <td>
                                            <asp:DropDownList ID="ddlSubjectNoFrom" runat="server" Width="80px">
                                            </asp:DropDownList>
                                            To
                                            <asp:DropDownList ID="ddlSubjectNoTo" runat="server" Width="80px">
                                            </asp:DropDownList>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td colspan="2" style="text-align: center;">
                                            <asp:Button ID="btnView" runat="server" Text="View" OnClick="btnView_Click" CssClass="button" />
                                            <asp:Button ID="btnGenerateReport" runat="server" Text="Generate" OnClick="btnGenerateReport_Click"
                                                CssClass="button" />
                                        </td>
                                    </tr>
                                </table>
                            </div>
                        </asp:Panel>
                        <asp:Panel ID="pnlViewReport" runat="server">
                            <div class="divRow">
                                <asp:GridView ID="grvMinutes" runat="server" AutoGenerateColumns="false" CssClass="contentTable1"
                                    AllowSorting="true" CellPadding="4" DataKeyNames="MeetingId" Font-Names="Verdana, Arial, Helvetica, sans-serif"
                                    Font-Size="X-Small" ForeColor="#333333" GridLines="Horizontal" Height="32px"
                                    Width="100%" OnSorting="grvRecord_Sorting">
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
                                                <asp:LinkButton ID="LinkButton1" runat="server" Text="Meeting No" CommandName="Sort"
                                                    Style="color: White" CommandArgument="MeetingNo"></asp:LinkButton>
                                            </HeaderTemplate>
                                            <ItemTemplate>
                                                <asp:Label ID="lblMeetingNoe" SkinID="lblSkinGen" Text='<%#Eval("MeetingNo")%>' runat="server" />
                                                <asp:HiddenField ID="hdnMeetingNo" runat="server" />
                                            </ItemTemplate>
                                            <ItemStyle Width="70px" CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                        </asp:TemplateField>
                                        <asp:TemplateField SortExpression="MeetingDate">
                                            <HeaderTemplate>
                                                <asp:LinkButton ID="LinkButton2" runat="server" Text="Meeting Date" CommandName="Sort"
                                                    Style="color: White" CommandArgument="MeetingDate"></asp:LinkButton>
                                            </HeaderTemplate>
                                            <ItemTemplate>
                                                <asp:Label ID="lblMeetingDate" runat="server" SkinID="lblskingen" Text='<%#Eval("MeetingDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                                <%--&nbsp; / &nbsp;
                                                <asp:Label ID="lblMeetingTime" runat="server" SkinID="lblskingen" Text='<%#Eval("MeetingTime")%>'></asp:Label>
                                                Hrs.--%>
                                            </ItemTemplate>
                                            <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                        </asp:TemplateField>
                                        <asp:TemplateField SortExpression="AgendaNo">
                                            <HeaderTemplate>
                                                <asp:LinkButton ID="LinkButton3" runat="server" Text="Agenda No" CommandName="Sort"
                                                    Style="color: White" CommandArgument="AgendaNo"></asp:LinkButton>
                                            </HeaderTemplate>
                                            <ItemTemplate>
                                                <asp:Label ID="lblAgendaNo" runat="server" SkinID="lblskingen" Text='<%#Eval("AgendaNo")%>'></asp:Label>
                                            </ItemTemplate>
                                            <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                        </asp:TemplateField>
                                        <asp:TemplateField SortExpression="SubjectNo">
                                            <HeaderTemplate>
                                                <asp:LinkButton ID="LinkButton4" runat="server" Text="Sub.No." CommandName="Sort"
                                                    Style="color: White" CommandArgument="SubjectNo"></asp:LinkButton>
                                            </HeaderTemplate>
                                            <ItemTemplate>
                                                <asp:Label ID="lblSubjectNo" runat="server" SkinID="lblskingen" Text='<%#Eval("SubjectNo")%>'></asp:Label>
                                            </ItemTemplate>
                                            <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                        </asp:TemplateField>
                                        <asp:TemplateField SortExpression="DepartmentName">
                                            <HeaderTemplate>
                                                <asp:LinkButton ID="LinkButton5" runat="server" CommandArgument="DepartmentName"
                                                    CommandName="Sort" Style="color: White" Text="Department Name"></asp:LinkButton>
                                            </HeaderTemplate>
                                            <ItemTemplate>
                                                <asp:Label ID="lblDepartmentName" runat="server" SkinID="lblskingen" Text='<%#Eval("DepartmentName")%>'></asp:Label>
                                            </ItemTemplate>
                                            <ItemStyle CssClass="contentTabletd" HorizontalAlign="Left" VerticalAlign="Middle" />
                                        </asp:TemplateField>
                                        <asp:TemplateField SortExpression="ShortText">
                                            <HeaderTemplate>
                                                <asp:LinkButton ID="LinkButton6" runat="server" CommandArgument="ShortText" CommandName="Sort"
                                                    Style="color: White" Text="Agenda Short Text"></asp:LinkButton>
                                            </HeaderTemplate>
                                            <ItemTemplate>
                                                <asp:Label ID="lblShortText" runat="server" SkinID="lblskingen" Text='<%#Eval("ShortText")%>'></asp:Label>
                                            </ItemTemplate>
                                            <ItemStyle Width="450px" CssClass="contentTabletd" HorizontalAlign="Left" VerticalAlign="Middle" />
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
