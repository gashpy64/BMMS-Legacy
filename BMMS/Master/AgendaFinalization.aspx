<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="AgendaFinalization.aspx.cs" Inherits="BMMS.Master.AgendaFinalization"
    Title="Untitled Page" ValidateRequest="false" %>

<%@ Register Assembly="FreeTextBox" Namespace="FreeTextBoxControls" TagPrefix="FTB" %>
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
            <div class="formContent">
                <div class="formPanel">
                    <div class="divHeader">
                        :: Agenda Finalization</div>
                    <div class="divRowFixed">
                    </div>
                    <div class="divRow" style="height: 25px">
                        <div id="divErrLogin" runat="server" class="divErrorHide">
                            <span id="spanErrLogin" runat="server" class="lblError"></span>
                        </div>
                    </div>
                    <asp:Panel ID="pnlAgendaFinalize" runat="server">
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
                                    <br />
                                    <asp:Button ID="btnFinalize" runat="server" CssClass="button" Text="Finalize" OnClick="btnFinalize_Click"
                                        OnClientClick="return confirm('Do you want to Finalize this Meeting Agenda?');" />
                                    <asp:Button ID="btnCancel" runat="server" CssClass="button" Text="Cancel" OnClick="btnCancel_Click" />
                                </div>
                            </div>
                            <div class="divRow" style="width: 90%; margin-left: 50px;">
                                <asp:Panel ID="pnlPendingAgenda" runat="server" Visible="false">
                                    <div class="divRow">
                                        Pending Agenda Details :
                                    </div>
                                    <div class="divRow">
                                        <div class="divRowGridScroll">
                                            <asp:GridView ID="grvAgenda" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                                                CssClass="contentTable1" AllowSorting="true" CellPadding="4" DataKeyNames="AgendaId"
                                                Font-Names="Verdana, Arial, Helvetica, sans-serif" Font-Size="X-Small" ForeColor="#333333"
                                                GridLines="Horizontal" Height="32px" Width="100%" OnRowDataBound="grvAgenda_RowDataBound"
                                                OnSorting="grvRecord_Sorting">
                                                <HeaderStyle CssClass="contentTableHeader" HorizontalAlign="Center" Font-Bold="true" />
                                                <Columns>
                                                    <asp:TemplateField HeaderText="S.No.">
                                                        <ItemTemplate>
                                                            <%# Container.DataItemIndex+1 + "."%>
                                                        </ItemTemplate>
                                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                                            Width="10px" />
                                                    </asp:TemplateField>
                                                    <asp:TemplateField SortExpression="AgendaNo">
                                                        <HeaderTemplate>
                                                            <asp:LinkButton ID="lnk1" runat="server" Text="Agenda No" CommandName="Sort" Style="color: White"
                                                                CommandArgument="AgendaNo"></asp:LinkButton>
                                                        </HeaderTemplate>
                                                        <ItemTemplate>
                                                            <asp:Label ID="lblAgendaNo" SkinID="lblSkinGen" Text='<%#Eval("AgendaNo")%>' runat="server" />
                                                            <asp:HiddenField ID="hdnAgendaId" runat="server" />
                                                        </ItemTemplate>
                                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                                    </asp:TemplateField>
                                                    <asp:TemplateField SortExpression="CommitteeName">
                                                        <HeaderTemplate>
                                                            <asp:LinkButton ID="lnk2" runat="server" Text="Committee Name" CommandName="Sort"
                                                                Style="color: White" CommandArgument="CommitteeName"></asp:LinkButton>
                                                        </HeaderTemplate>
                                                        <ItemTemplate>
                                                            <asp:Label ID="lblCommitteeName" runat="server" SkinID="lblskingen" Text='<%#Eval("CommitteeName")%>'></asp:Label>
                                                        </ItemTemplate>
                                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                                    </asp:TemplateField>
                                                    <asp:TemplateField SortExpression="MeetingNo">
                                                        <HeaderTemplate>
                                                            <asp:LinkButton ID="lnk3" runat="server" Text="MeetingNo" CommandName="Sort" Style="color: White"
                                                                CommandArgument="StatusId"></asp:LinkButton>
                                                        </HeaderTemplate>
                                                        <ItemTemplate>
                                                            <asp:Label ID="lblMeetingNo" runat="server" SkinID="lblskingen" Text='<%#Eval("MeetingNo") %>'></asp:Label>
                                                        </ItemTemplate>
                                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                                    </asp:TemplateField>
                                                    <asp:TemplateField SortExpression="SubjectTypeName">
                                                        <HeaderTemplate>
                                                            <asp:LinkButton ID="lnk4" runat="server" Text="Subject Type Name" CommandName="Sort"
                                                                Style="color: White" CommandArgument="SubjectTypeName"></asp:LinkButton>
                                                        </HeaderTemplate>
                                                        <ItemTemplate>
                                                            <asp:Label ID="lblSubjectTypeName" runat="server" SkinID="lblskingen" Text='<%#Eval("SubjectTypeName") %>'></asp:Label>
                                                        </ItemTemplate>
                                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                                    </asp:TemplateField>
                                                    <asp:TemplateField SortExpression="ShortText">
                                                        <HeaderTemplate>
                                                            <asp:LinkButton ID="lnk5" runat="server" Text="Short Text" CommandName="Sort" Style="color: White"
                                                                CommandArgument="ShortText"></asp:LinkButton>
                                                        </HeaderTemplate>
                                                        <ItemTemplate>
                                                            <asp:Label ID="lblShortText" runat="server" SkinID="lblskingen" Text='<%#Eval("ShortText") %>'></asp:Label>
                                                        </ItemTemplate>
                                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Justify" />
                                                    </asp:TemplateField>
                                                    <asp:TemplateField SortExpression="AgendaStatusName">
                                                        <HeaderTemplate>
                                                            <asp:LinkButton ID="lnk6" runat="server" Text="Agenda Status" CommandName="Sort"
                                                                Style="color: White" CommandArgument="AgendaStatusName"></asp:LinkButton>
                                                        </HeaderTemplate>
                                                        <ItemTemplate>
                                                            <asp:Label ID="lblAgendaStatusName" runat="server" SkinID="lblskingen" Text='<%#Eval("AgendaStatusName") %>'></asp:Label>
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
                                </asp:Panel>
                            </div>
                        </div>
                    </asp:Panel>
                </div>
            </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
