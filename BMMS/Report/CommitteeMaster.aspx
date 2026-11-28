<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="CommitteeMaster.aspx.cs" Inherits="BMMS.Report.CommitteeMaster" Title="Untitled Page" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <asp:Panel ID="pnlCommitteeMaster" runat="server">
                <%-- Step UI2b: the Masters' form look (Committee Master): breadcrumb and title as in the menu, a card with
                     label and field rows, Submit as the primary button. Control IDs, events and the handlers are unchanged. --%>
                <div class="wb-page wb-page-fit">
                    <div class="wb-breadcrumb">
                        Reports<span class="wb-breadcrumb-sep">/</span>Committee Master</div>
                    <h1 class="wb-h1">
                        Committee Master</h1>
                    <div class="wb-card">
                        <div class="wb-card-header">
                            Filter</div>
                        <div class="wb-card-body">
                            <div class="wb-row">
                                <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlCommittee">
                                    Committee</label>
                                <div class="wb-field">
                                    <asp:DropDownList ID="ddlCommittee" runat="server" AutoPostBack="true"
                                        OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                                    </asp:DropDownList>
                                </div>
                            </div>
                            <div class="wb-row">
                                <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlStatus">
                                    Status</label>
                                <div class="wb-field">
                                    <asp:DropDownList ID="ddlStatus" runat="server" AutoPostBack="true"
                                        OnSelectedIndexChanged="ddlStatus_SelectedIndexChanged">
                                    </asp:DropDownList>
                                </div>
                            </div>
                            <div class="wb-actions">
                                <asp:Button ID="btnSubmit" runat="server" CssClass="wb-btn" Text="Submit" OnClick="btnSubmit_Click" />
                            </div>
                        </div>
                    </div>
                </div>
                <%-- Step UI2b (R12): the grid keeps its old frame and look, outside .wb-page --%>
                <div class="formContent">
                <div class="formPanel">
                    <div class="divRow">
                        <asp:GridView ID="grvCommittee" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                            CssClass="contentTable1" AllowSorting="true" CellPadding="4" DataKeyNames="CommitteeId"
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
                                <asp:TemplateField SortExpression="CommitteeCode">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="lnk1" runat="server" Text="Committee Code" CommandName="Sort"
                                            Style="color: White" CommandArgument="CommitteeCode"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblCommitteeCode" SkinID="lblSkinGen" Text='<%# HttpUtility.HtmlEncode(Eval("CommitteeCode")) %>'
                                            runat="server" />
                                        <asp:HiddenField ID="hdnCommitteeId" runat="server" Value='<%#Eval("CommitteeId")%>' />
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="CommitteeName">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="lnk2" runat="server" Text="Committee Name" CommandName="Sort"
                                            Style="color: White" CommandArgument="CommitteeName"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblCommitteeName" SkinID="lblSkinGen" Text='<%# HttpUtility.HtmlEncode(Eval("CommitteeName")) %>'
                                            runat="server" />
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="IncorporationDate">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="lnk3" runat="server" Text="Incorporation Date" CommandName="Sort"
                                            Style="color: White" CommandArgument="IncorporationDate"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblIncorporationDate" runat="server" SkinID="lblskingen" Text='<%#Eval("IncorporationDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="CessationDate">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="lnk4" runat="server" Text="Cessation Date" CommandName="Sort"
                                            Style="color: White" CommandArgument="CessationDate"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblCessationDate" runat="server" SkinID="lblskingen" Text='<%#Eval("CessationDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="StatusName">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="lnk5" runat="server" Text="Status Name" CommandName="Sort" Style="color: White"
                                            CommandArgument="StatusName"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblStatusName" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("StatusName")) %>'></asp:Label>
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
