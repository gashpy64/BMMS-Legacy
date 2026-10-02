<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="DecisionType.aspx.cs" Inherits="BMMS.Master.DecisionType" Title="Untitled Page" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="formContent">
    <div class="formPanel">
        <div class="divHeader">
        :: Decision Type Master</div>
        <div class="divRowFixed"></div> 
        <div class="divRow" style="height: 25px">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
        </div>
        <asp:Panel ID="pnlViewDecisionType" runat="server">
            <div class="divRow" style="margin: auto; float: none; width: 700px;">
                <%if (Session["RoleCode"].ToString() == "admin")
                  { %>
                <div class="divRow">
                    <asp:Button ID="btnAdd" runat="server" CssClass="button" Text="Add" OnClick="btnAdd_Click" />
                </div>
                <%
                    } %>
                <div class="divRow">
                    <asp:GridView ID="grvDecisionType" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                        CssClass="contentTable1" AllowSorting="true" CellPadding="4" DataKeyNames="DecisionTypeId"
                        Font-Names="Verdana, Arial, Helvetica, sans-serif" Font-Size="X-Small" ForeColor="#333333" GridLines="Horizontal"
                        Height="32px" Width="100%" OnRowDataBound="grvDecisionType_RowDataBound" OnSorting="grvRecord_Sorting"
                        OnRowCommand="grvDecisionType_RowCommand">
                        <HeaderStyle CssClass="contentTableHeader" HorizontalAlign="Center" Font-Bold="true" />
                        <Columns>
                            <asp:TemplateField HeaderText="S.No.">
                                <ItemTemplate>
                                    <%# Container.DataItemIndex+1 + "."%>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                    Width="10px" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="DecisionTypeCode">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk1" runat="server" Text="DecisionType Code" CommandName="Sort"
                                        Style="color: White" CommandArgument="DecisionTypeCode"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblDecisionTypeCode" SkinID="lblSkinGen" Text='<%#Eval("DecisionTypeCode")%>'
                                        runat="server" />
                                    <asp:HiddenField ID="hdnDecisionTypeCode" runat="server" />
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="DecisionTypeName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk2" runat="server" Text="DecisionType Name" CommandName="Sort"
                                        Style="color: White" CommandArgument="DecisionTypeName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblEmployeName" runat="server" SkinID="lblskingen" Text='<%#Eval("DecisionTypeName")%>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="StatusName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk4" runat="server" Text="Status" CommandName="Sort" Style="color: White"
                                        CommandArgument="StatusName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblStatusName" runat="server" SkinID="lblskingen" Text='<%#Eval("StatusName")%>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnEdit" Width="18px" Height="18px" CssClass="buttonEdit" ToolTip="Edit" CommandArgument='<%#Eval("DecisionTypeId")%>'
                                        runat="server" CommandName="EditRec" />
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                    Width="30px" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnDelete" Width="18px" Height="18px" CssClass="buttonDelete"  ToolTip="Delete" CommandArgument='<%#Eval("DecisionTypeId")%>'
                                        runat="server" CommandName="DeleteRec" OnClientClick="return confirm('Are you sure you want to delete this UserRecord?');" />
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
        <asp:Panel ID="pnlEditDecisionType" runat="server">
            <div class="divRow">
                <div class="divRow">
                    <div class="divRow">
                        <div class="divRowLeft">
                            Decision Type Code :
                        </div>
                        <div class="divRowRight">
                            <asp:TextBox ID="txtDecisionTypeCode" runat="server" MaxLength="6" ReadOnly="true"></asp:TextBox>
                            <asp:HiddenField ID="hdnDecisionTypeId" runat="server" />
                        </div>
                    </div>
                </div>
                <div class="divRow">
                    <div class="divRow">
                        <div class="divRowLeft">
                            Decision Type Name :
                        </div>
                        <div class="divRowRight">
                            <asp:TextBox ID="txtDecisionTypeName" runat="server"></asp:TextBox>
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
