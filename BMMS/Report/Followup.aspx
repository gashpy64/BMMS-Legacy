<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="Followup.aspx.cs" Inherits="BMMS.Report.Followup" Title="Untitled Page" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
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
                        <div class="divRowFixed">
                        </div>
                        <div class="divRow" style="height: 25px">
                            <div id="divErrLogin" runat="server" class="divErrorHide">
                                <span id="spanErrLogin" runat="server" class="lblError"></span>
                            </div>
                        </div>
                        <div class="divRow">
                            <asp:Panel ID="pnlFollowupFilter" runat="server">
                                <div class="divRow">
                                    <table cellspacing="12" cellpadding="0" border="0" width="100%">
                                        <tr>
                                            <td class="Lable" style="width: 20%">
                                                Meeting Date From :
                                            </td>
                                            <td style="width: 30%">
                                                <table>
                                                    <tr>
                                                        <td>
                                                            <asp:TextBox ID="txtFromDate" runat="server" Width="80px" onfocus="this.blur();"
                                                                TabIndex="-1"></asp:TextBox>
                                                        </td>
                                                        <td>
                                                            <asp:ImageButton runat="Server" ID="imgFromDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                                        </td>
                                                        <td>
                                                            <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender1" runat="server"
                                                                TargetControlID="txtFromDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                                                PopupButtonID="imgFromDate">
                                                            </cc1:CalendarExtender>
                                                        </td>
                                                        <td>
                                                            to
                                                        </td>
                                                        <td>
                                                            <asp:TextBox ID="txtToDate" runat="server" Width="80px" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                                                        </td>
                                                        <td>
                                                            <asp:ImageButton runat="Server" ID="imgToDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                                            <span class="spanMandatory">*</span>
                                                        </td>
                                                        <td>
                                                            <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender2" runat="server"
                                                                TargetControlID="txtToDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                                                PopupButtonID="imgToDate">
                                                            </cc1:CalendarExtender>
                                                        </td>
                                                    </tr>
                                                </table>
                                            </td>
                                            <td class="Lable" style="width: 15%">
                                                Committee Name :
                                            </td>
                                            <td style="width: 35%">
                                                <asp:DropDownList ID="ddlCommittee" runat="server" Width="300px" AutoPostBack="true"
                                                    OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                                                </asp:DropDownList>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td class="Lable">
                                                Meeting No. Search :
                                            </td>
                                            <td>
                                                <asp:RadioButtonList ID="rdoMeatingNoSearch" runat="server" RepeatDirection="Horizontal"
                                                    AutoPostBack="true" OnSelectedIndexChanged="rdoMeatingNoSearch_SelectedIndexChanged">
                                                    <asp:ListItem Text="Particular" Value="0" Selected="True"></asp:ListItem>
                                                    <asp:ListItem Text="Between" Value="1"></asp:ListItem>
                                                </asp:RadioButtonList>
                                            </td>
                                            <td class="Lable">
                                                Department :
                                            </td>
                                            <td>
                                                <asp:DropDownList ID="ddlDepartment" runat="server" Width="300px">
                                                </asp:DropDownList>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td class="Lable">
                                                Meeting No. :
                                            </td>
                                            <td>
                                                <asp:Panel ID="pnlMeetingNoParticular" runat="server">
                                                    <asp:DropDownList ID="ddlMeetingNo" runat="server" Width="80px">
                                                    </asp:DropDownList>
                                                </asp:Panel>
                                                <asp:Panel ID="pnlMeetingNoBetween" runat="server">
                                                    <asp:DropDownList ID="ddlMeetingNoFrom" runat="server" Width="80px">
                                                    </asp:DropDownList>
                                                    <asp:Label ID="lblMeetingNo" runat="server" Text=" to "></asp:Label>
                                                    <asp:DropDownList ID="ddlMeetingNoTo" runat="server" Width="80px">
                                                    </asp:DropDownList>
                                                </asp:Panel>
                                            </td>
                                            <td class="Lable">
                                                Confirmed Status :
                                            </td>
                                            <td colspan="3">
                                                <asp:RadioButtonList ID="rdoConfirmStatus" runat="server" RepeatDirection="Horizontal">
                                                    <asp:ListItem Text="Both" Value="-1" Selected="True"></asp:ListItem>
                                                    <asp:ListItem Text="Confirmed" Value="1"></asp:ListItem>
                                                    <asp:ListItem Text="Not Confirmed" Value="0"></asp:ListItem>
                                                </asp:RadioButtonList>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td colspan="4" style="text-align: center;">
                                                <asp:Button ID="btnViewFollowup" runat="server" Text="View" OnClick="btnViewFollowup_Click"
                                                    CssClass="button" />
                                                <asp:Button ID="btnGenerateReport" runat="server" Text="Generate" OnClick="btnGenerateReport_Click"
                                                    CssClass="button" />
                                                <asp:Button ID="btnCancel" runat="server" CssClass="button" Text="Cancel" OnClick="btnCancel_Click" />
                                            </td>
                                        </tr>
                                    </table>
                                </div>
                            </asp:Panel>
                        </div>
                        <div class="divRow">
                            <asp:Panel ID="pnlViewFollowup" runat="server">
                                <div class="divRow">
                                    <asp:GridView ID="grvFollowup" runat="server" AutoGenerateColumns="false" CssClass="contentTable1"
                                        AllowSorting="true" CellPadding="4" DataKeyNames="MeetingId" Font-Names="Verdana, Arial, Helvetica, sans-serif"
                                        Font-Size="X-Small" ForeColor="#333333" GridLines="Horizontal" Height="32px"
                                        Width="100%" OnSorting="grvRecord_Sorting">
                                        <HeaderStyle CssClass="contentTableHeader" HorizontalAlign="Center" Font-Bold="true" />
                                        <Columns>
                                            <asp:TemplateField HeaderText="S.No.">
                                                <ItemTemplate>
                                                    <%# Container.DataItemIndex+1 + "."%>
                                                </ItemTemplate>
                                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Top" HorizontalAlign="Center"
                                                    Width="10px" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="CommitteeName">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="LinkButton1" runat="server" Text="Committee Name" CommandName="Sort"
                                                        Style="color: White" CommandArgument="CommitteeName"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblCommitteeName" SkinID="lblSkinGen" Text='<%#Eval("CommitteeName")%>' runat="server" />
                                                </ItemTemplate>
                                                <ItemStyle Width="100px" CssClass="contentTabletd" VerticalAlign="Top" HorizontalAlign="Left" />
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
                                                <ItemStyle Width="70px" CssClass="contentTabletd" VerticalAlign="Top" HorizontalAlign="Center" />
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
                                                <ItemStyle Width="90px" CssClass="contentTabletd" VerticalAlign="Top" HorizontalAlign="Center" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="AgendaNo">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="LinkButton3" runat="server" Text="Agenda No" CommandName="Sort"
                                                        Style="color: White" CommandArgument="AgendaNo"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblAgendaNo" runat="server" SkinID="lblskingen" Text='<%#Eval("AgendaNo")%>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle Width="100px" CssClass="contentTabletd" VerticalAlign="Top" HorizontalAlign="Center" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="SubjectNo">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="LinkButton4" runat="server" Text="Sub.No." CommandName="Sort"
                                                        Style="color: White" CommandArgument="SubjectNo"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblSubjectNo" runat="server" SkinID="lblskingen" Text='<%#Eval("SubjectNo")%>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle Width="50px" CssClass="contentTabletd" VerticalAlign="Top" HorizontalAlign="Center" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="DepartmentName">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="LinkButton5" runat="server" CommandArgument="DepartmentName"
                                                        CommandName="Sort" Style="color: White" Text="Dept. Name"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblDepartmentName" runat="server" SkinID="lblskingen" Text='<%#Eval("DepartmentName")%>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle Width="100px" CssClass="contentTabletd" HorizontalAlign="Left" VerticalAlign="Top" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="ShortText">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="LinkButton6" runat="server" CommandArgument="ShortText" CommandName="Sort"
                                                        Style="color: White" Text="Agenda Short Text"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblShortText" runat="server" SkinID="lblskingen" Text='<%#Eval("ShortText")%>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle CssClass="contentTabletd" HorizontalAlign="justify" VerticalAlign="Top" />
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
            </asp:Panel>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
