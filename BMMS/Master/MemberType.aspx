<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="MemberType.aspx.cs" Inherits="BMMS.Master.MemberType" Title="Untitled Page" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="formContent">
    <div class="formPanel">
        <div class="divHeader">
        :: Member Type Master</div>
        <div class="divRowFixed"></div> 
        <div class="divRow" style="height: 25px">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
        </div>
        <asp:Panel ID="pnlViewMemberType" runat="server">
            <div class="divRow" style="margin: auto; float: none; width: 700px;">
                <div class="divRow">
                    <asp:Button ID="btnAdd" runat="server" CssClass="button" Text="Add" OnClick="btnAdd_Click" />
                </div>
                <div class="divRow">
                    <asp:GridView ID="grvMemberType" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                        CssClass="contentTable1" AllowSorting="true" CellPadding="4" DataKeyNames="MemberTypeId"
                        Font-Names="Verdana, Arial, Helvetica, sans-serif" Font-Size="X-Small" ForeColor="#333333" GridLines="Horizontal"
                        Height="32px" Width="100%" OnRowDataBound="grvMemberType_RowDataBound" OnSorting="grvRecord_Sorting"
                        OnRowCommand="grvMemberType_RowCommand">
                        <HeaderStyle CssClass="contentTableHeader" HorizontalAlign="Center" Font-Bold="true" />
                        <Columns>
                            <asp:TemplateField HeaderText="S.No.">
                                <ItemTemplate>
                                    <%# Container.DataItemIndex+1 + "."%>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                    Width="10px" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="MemberTypeCode">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk1" runat="server" Text="MemberType Code" CommandName="Sort"
                                        Style="color: White" CommandArgument="MemberTypeCode"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblMemberTypeCode" SkinID="lblSkinGen" Text='<%#Eval("MemberTypeCode")%>'
                                        runat="server" />
                                    <asp:HiddenField ID="hdnMemberTypeCode" runat="server" />
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="MemberTypeName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk2" runat="server" Text="MemberType Name" CommandName="Sort"
                                        Style="color: White" CommandArgument="MemberTypeName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblEmployeName" runat="server" SkinID="lblskingen" Text='<%#Eval("MemberTypeName")%>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="StatusName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk4" runat="server" Text="Status" CommandName="Sort"
                                        Style="color: White" CommandArgument="StatusName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblStatusName" runat="server" SkinID="lblskingen" Text='<%#Eval("StatusName")%>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnEdit" Width="18px" Height="18px" CssClass="buttonEdit" ToolTip="Edit" CommandArgument='<%#Eval("MemberTypeId")%>'
                                        runat="server" CommandName="EditRec" />
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                    Width="30px" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnDelete" Width="18px" Height="18px" CssClass="buttonDelete"  ToolTip="Delete" CommandArgument='<%#Eval("MemberTypeId")%>'
                                        runat="server" CommandName="DeleteRec" OnClientClick="return confirm('Are you sure you want to delete this Record?');" />
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                    Width="30px" />
                            </asp:TemplateField>
                        </Columns>
                        <EmptyDataTemplate>
                            <div class="divNoRecord">
                                <%#Session["NoRecord"].ToString()%></div>
                        </EmptyDataTemplate>
                    </asp:GridView>
                </div>
            </div>
        </asp:Panel>
        <asp:Panel ID="pnlEditMemberType" runat="server">
            <div class="divRow">
                <div class="divRow">
                    <div class="divRow">
                        <div class="divRowLeft">
                            Member Type Code :
                        </div>
                        <div class="divRowRight">
                            <asp:TextBox ID="txtMemberTypeCode" runat="server"></asp:TextBox>
                            <asp:HiddenField ID="hdnMemberTypeId" runat="server" />
                            <span class="spanMandatory">*</span>
                        </div>
                    </div>
                </div>
                <div class="divRow">
                    <div class="divRow">
                        <div class="divRowLeft">
                            Member Type Name :
                        </div>
                        <div class="divRowRight">
                            <asp:TextBox ID="txtMemberTypeName" runat="server"></asp:TextBox>
                            <span class="spanMandatory">*</span>
                        </div>
                    </div>
                </div>
                <div class="divRow">
                    <div class="divRow">
                        <div class="divRowLeft">
                            Status :
                        </div>
                        <div class="divRowRight">
                            <asp:DropDownList ID="ddlStatus" runat="server" Width="150px">
                            </asp:DropDownList>
                        </div>
                    </div>
                </div>
                <div class="divRow">
                    <div class="divRow">
                        <div class="divRowLeft">
                            <span class="spanWhite">.</span>
                        </div>
                        <div class="divRowRight">
                            <asp:Button ID="btnSave" runat="server" CssClass="button" Text="Save" OnClick="btnSave_Click" />
                            <asp:Button ID="btnCancel" runat="server" CssClass="button" Text="Cancel" OnClick="btnCancel_Click" />
                        </div>
                    </div>
                </div>
            </div>
        </asp:Panel>
    </div>
    </div>
</asp:Content>
