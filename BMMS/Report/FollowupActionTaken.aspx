<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="FollowupActionTaken.aspx.cs" Inherits="BMMS.Report.FollowupActionTaken" Title="Followup by Department" %>

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
                            :: Followup by Department</div>
                        <div class="divRowFixed">
                        </div>
                        <div class="divRow" style="height: 25px">
                            <div id="divErrLogin" runat="server" class="divErrorHide">
                                <span id="spanErrLogin" runat="server" class="lblError"></span>
                            </div>
                        </div>
                        <div class="divRow">
                            <table border="0" cellpadding="0" cellspacing="12" width="100%">
                                <tr>
                                    <td class="Lable wb-label">
                                        Committee :</td>
                                    <td>
                                        <asp:DropDownList ID="ddlCommittee" runat="server" CssClass="wb-filter-select" AutoPostBack="true"
                                            OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                                        </asp:DropDownList>&nbsp;
                                    </td>
                                    <td class="Lable wb-label">
                                        Department :</td>
                                    <td>
                                        <asp:DropDownList ID="ddlDeparment" runat="server" CssClass="wb-filter-select" AutoPostBack="true"
                                            OnSelectedIndexChanged="ddlDeparment_SelectedIndexChanged">
                                        </asp:DropDownList></td>
                                </tr>
                                <tr>
                                    <td class="Lable wb-label">
                                        Meeting No. Search :</td>
                                    <td>
                                        <asp:RadioButtonList ID="rdoMeatingNoSearch" runat="server" RepeatDirection="Horizontal"
                                            AutoPostBack="true" OnSelectedIndexChanged="rdoMeatingNoSearch_SelectedIndexChanged">
                                            <asp:ListItem Text="Particular" Value="0" Selected="True"></asp:ListItem>
                                            <asp:ListItem Text="Between" Value="1"></asp:ListItem>
                                        </asp:RadioButtonList>
                                    </td>
                                    <td class="Lable wb-label">
                                        Subject No. Search :</td>
                                    <td>
                                        <asp:RadioButtonList ID="rdoSubjectNoSearch" runat="server" RepeatDirection="Horizontal"
                                            AutoPostBack="true" OnSelectedIndexChanged="rdoSubjectNoSearch_SelectedIndexChanged">
                                            <asp:ListItem Text="All" Value="0" Selected="True"></asp:ListItem>
                                            <asp:ListItem Text="Between" Value="1"></asp:ListItem>
                                        </asp:RadioButtonList>
                                    </td>
                                </tr>
                                <tr>
                                    <td class="Lable wb-label">
                                        Meeting No :</td>
                                    <td>
                                        <asp:DropDownList ID="ddlMeetingNoFrom" runat="server" CssClass="wb-filter-select wb-filter-short" AutoPostBack="true"
                                            DataTextField="SubjectNo" DataValueField="SubjectNo" OnSelectedIndexChanged="ddlMeetingNoFrom_SelectedIndexChanged">
                                        </asp:DropDownList>
                                        <asp:Label ID="lblMeetingNo" runat="server" Text=" to "></asp:Label>
                                        <asp:DropDownList ID="ddlMeetingNoTo" runat="server" CssClass="wb-filter-select wb-filter-short" AutoPostBack="true"
                                            DataTextField="SubjectNo" DataValueField="SubjectNo" OnSelectedIndexChanged="ddlMeetingNoTo_SelectedIndexChanged">
                                        </asp:DropDownList></td>
                                    <td class="Lable wb-label">
                                        Subject No. :</td>
                                    <td>
                                        <asp:DropDownList ID="ddlSubjectNoFrom" runat="server" CssClass="wb-filter-select wb-filter-short" AutoPostBack="true"
                                            DataTextField="SubjectNo" DataValueField="SubjectNo">
                                        </asp:DropDownList>
                                        To
                                        <asp:DropDownList ID="ddlSubjectNoTo" runat="server" CssClass="wb-filter-select wb-filter-short" AutoPostBack="true"
                                            DataTextField="SubjectNo" DataValueField="SubjectNo">
                                        </asp:DropDownList></td>
                                </tr>
                                <tr>
                                    <td class="Lable wb-label">
                                        View Format :</td>
                                    <td>
                                        <asp:RadioButtonList ID="rdoViewFormat" runat="server" AutoPostBack="True" RepeatDirection="Horizontal">
                                            <asp:ListItem Text="View" Value="View" Selected="True"></asp:ListItem>
                                            <asp:ListItem Text="Print" Value="Print"></asp:ListItem>
                                        </asp:RadioButtonList>
                                    </td>
                                    <td>
                                    </td>
                                    <td>
                                    </td>
                                </tr>
                                <tr>
                                    <td colspan="4" style="text-align: center;">
                                        <asp:Button ID="btnSubmit" runat="server" Text="Submit" OnClick="btnSubmit_Click"
                                            CssClass="button" />
                                    </td>
                                </tr>
                            </table>
                            <asp:Panel ID="pnlPrintReport" runat="server" Visible="false">
                                <table border="0" cellpadding="0" cellspacing="12" width="100%">
                                    <tr>
                                        <td colspan="2" style="text-align:center;">
                                            <asp:Button ID="btnCreatePDF" runat="server" Text="Generate Report" OnClick="btnCreatePDF_Click"
                                                CssClass="button" />
                                        </td>
                                    </tr>
                                    <tr>
                                        <td>
                                            &nbsp;</td>
                                        <td style="">
                                            <br />
                                            <br />
                                        </td>
                                    </tr>
                                </table>
                            </asp:Panel>
                            <asp:Panel ID="pnlViewReport" runat="server">
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
                                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                                    Width="10px" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="MeetingNo">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="LinkButton1" runat="server" Text="Meeting No" CommandName="Sort"
                                                        Style="color: White" CommandArgument="MeetingNo"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblMeetingNoe" SkinID="lblSkinGen" Text='<%# HttpUtility.HtmlEncode(Eval("MeetingNo")) %>' runat="server" />
                                                    <asp:HiddenField ID="hdnMeetingNo" runat="server" />
                                                </ItemTemplate>
                                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="MeetingDate">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="LinkButton2" runat="server" Text="Meeting Date / Time" CommandName="Sort"
                                                        Style="color: White" CommandArgument="MeetingDate"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblMeetingDate" runat="server" SkinID="lblskingen" Text='<%#Eval("MeetingDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                                    &nbsp; / &nbsp;
                                                    <asp:Label ID="lblMeetingTime" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("MeetingTime")) %>'></asp:Label>
                                                    Hrs.
                                                </ItemTemplate>
                                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="AgendaNo">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="LinkButton3" runat="server" Text="Agenda No" CommandName="Sort"
                                                        Style="color: White" CommandArgument="AgendaNo"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblAgendaNo" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("AgendaNo")) %>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="SubjectNo">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="LinkButton4" runat="server" Text="Subject No" CommandName="Sort"
                                                        Style="color: White" CommandArgument="SubjectNo"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblSubjectNo" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("SubjectNo")) %>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="DepartmentName">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="LinkButton5" runat="server" CommandArgument="DepartmentName"
                                                        CommandName="Sort" Style="color: White" Text="Department Name"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblDepartmentName" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("DepartmentName")) %>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle CssClass="contentTabletd" HorizontalAlign="Left" VerticalAlign="Middle" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="ShortText">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="LinkButton6" runat="server" CommandArgument="ShortText" CommandName="Sort"
                                                        Style="color: White" Text="Agenda Short Text"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblShortText" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("ShortText")) %>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle CssClass="contentTabletd" HorizontalAlign="Left" VerticalAlign="Middle" />
                                            </asp:TemplateField>
                                            <%-- Step FU2b: the Followup status of the item, as the Followup page shows it: the word and the
                                                 line of who confirmed or reopened it. Headed "Followup status", as on the Followup report. Built and encoded in
                                                 StatusCellHtml --%>
                                            <asp:TemplateField HeaderText="Followup status">
                                                <ItemTemplate>
                                                    <asp:Literal ID="litStatus" runat="server" Mode="PassThrough" Text='<%# StatusCellHtml(Container.DataItem) %>'></asp:Literal>
                                                </ItemTemplate>
                                                <ItemStyle Width="220px" CssClass="contentTabletd wb-followup-status-cell" HorizontalAlign="Left" VerticalAlign="Middle" />
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
