<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="CommitteeMember.aspx.cs" Inherits="BMMS.Report.CommitteeMember" Title="Committee Member" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <asp:Panel ID="pnlCommitteeMaster" runat="server">
                <div class="formContent">
                <div class="formPanel">
                    <div class="divHeader">
                    :: Committee Members</div>
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
                        <asp:GridView ID="grvCommitteeMember" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
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
                                <asp:TemplateField SortExpression="MemberTypeName">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Member Type" CommandName="Sort" Style="color: White"
                                            CommandArgument="MemberTypeName"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblMemberTypeName" SkinID="lblSkinGen" Text='<%#Eval("MemberTypeName")%>' runat="server" />
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="MemberName">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Member Name" CommandName="Sort" Style="color: White"
                                            CommandArgument="MemberName"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblMemberName" runat="server" SkinID="lblskingen" Text='<%#Eval("MemberName")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="DesignationName">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Designation" CommandName="Sort" Style="color: White"
                                            CommandArgument="DesignationName"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblDesignationName" runat="server" SkinID="lblskingen" Text='<%#Eval("DesignationName")%>'></asp:Label>
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
