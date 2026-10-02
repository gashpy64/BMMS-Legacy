<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="CommitteeMaster.aspx.cs" Inherits="BMMS.Report.CommitteeMaster" Title="Untitled Page" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <asp:Panel ID="pnlCommitteeMaster" runat="server">
                <div class="formContent">
                <div class="formPanel">
                    <div class="divHeader">
                    :: Committee Master Report</div>
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
                                    Status :</td>
                                <td>
                                    <asp:DropDownList ID="ddlStatus" runat="server" Width="150px" AutoPostBack="true"
                                        OnSelectedIndexChanged="ddlStatus_SelectedIndexChanged">
                                    </asp:DropDownList></td>
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
                        <asp:GridView ID="grvCommittee" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                            CssClass="contentTable1" AllowSorting="true" CellPadding="4" DataKeyNames="CommitteeId"
                            Font-Names="Verdana, Arial, Helvetica, sans-serif" Font-Size="X-Small" ForeColor="#333333"
                            GridLines="Horizontal" Height="32px" Width="100%">
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
                                        <asp:Label ID="lblCommitteeCode" SkinID="lblSkinGen" Text='<%#Eval("CommitteeCode")%>'
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
                                        <asp:Label ID="lblCommitteeName" SkinID="lblSkinGen" Text='<%#Eval("CommitteeName")%>'
                                            runat="server" />
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="IncorporationDate">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="lnk2" runat="server" Text="Incorporation Date" CommandName="Sort"
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
                                        <asp:Label ID="lblStatusName" runat="server" SkinID="lblskingen" Text='<%#Eval("StatusName") %>'></asp:Label>
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
