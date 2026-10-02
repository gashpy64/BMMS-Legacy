<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="BackupDatabase.aspx.cs" Inherits="BMMS.Master.BackupDatabase" Title="BackupDatabase"
    ValidateRequest="false" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="formContent">
    <div class="formPanel">
    <div class="divHeader">
        :: Backup Database</div>
        <div class="divRowFixed"  style="height: 320px;"></div>
        <div style="text-align: center; padding-top: 10px; padding-bottom: 15px;">
            <asp:Button ID="btnBackupDatabase" runat="server" Text="Backup Database" CssClass="button"
                OnClick="btnBackupDatabase_Click" OnClientClick="return confirm('Are you sure to Create Database Backup?');" />
            <br />
            <br />
            <asp:Literal ID="ltrlNote" runat="server"></asp:Literal>
        </div>
        <div class="divRowGridScroll" style="height: 240px;">
            <asp:GridView ID="grvSqlBackup" runat="server" AutoGenerateColumns="false" CssClass="contentTable1"
                AllowSorting="true" CellPadding="4" DataKeyNames="Audit_Trail_SqlBackup_Id" Font-Names="Verdana, Arial, Helvetica, sans-serif"
                Font-Size="X-Small" ForeColor="#333333" GridLines="Horizontal" Height="32px"
                Width="100%">
                <HeaderStyle CssClass="contentTableHeader" HorizontalAlign="Center" Font-Bold="true" />
                <Columns>
                    <asp:TemplateField HeaderText="S.No.">
                        <ItemTemplate>
                            <%# Container.DataItemIndex+1 + "."%>
                        </ItemTemplate>
                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                            Width="10px" />
                    </asp:TemplateField>
                    <asp:TemplateField SortExpression="Backup_File_Name">
                        <HeaderTemplate>
                            <asp:LinkButton ID="lnk1" runat="server" Text="Backup File Name" CommandName="Sort"
                                Style="color: White" CommandArgument="Backup_File_Name"></asp:LinkButton>
                        </HeaderTemplate>
                        <ItemTemplate>
                            <asp:Label ID="lblBackup_File_Name" Text='<%#Eval("Backup_File_Name")%>' runat="server" />
                        </ItemTemplate>
                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                    </asp:TemplateField>
                    <asp:TemplateField SortExpression="UserName">
                        <HeaderTemplate>
                            <asp:LinkButton ID="lnk2" runat="server" Text="User Name" CommandName="Sort" Style="color: White"
                                CommandArgument="UserName"></asp:LinkButton>
                        </HeaderTemplate>
                        <ItemTemplate>
                            <asp:Label ID="lblUserName" SkinID="lblSkinGen" Text='<%#Eval("UserName")%>' runat="server" />
                        </ItemTemplate>
                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                    </asp:TemplateField>
                    <asp:TemplateField SortExpression="Backup_Date_Time">
                        <HeaderTemplate>
                            <asp:LinkButton ID="lnk2" runat="server" Text="Backup Date Time" CommandName="Sort"
                                Style="color: White" CommandArgument="Backup_Date_Time"></asp:LinkButton>
                        </HeaderTemplate>
                        <ItemTemplate>
                            <asp:Label ID="lblBackup_Date_Time" runat="server" SkinID="lblskingen" Text='<%#Eval("Backup_Date_Time", "{0:dd-MMM-yyyy HH:mm:ss}")%>'></asp:Label>
                        </ItemTemplate>
                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                    </asp:TemplateField>
                    <asp:TemplateField SortExpression="User_IP_Address">
                        <HeaderTemplate>
                            <asp:LinkButton ID="lnk4" runat="server" Text="User IP Address" CommandName="Sort"
                                Style="color: White" CommandArgument="User_IP_Address"></asp:LinkButton>
                        </HeaderTemplate>
                        <ItemTemplate>
                            <asp:Label ID="lblUser_IP_Address" runat="server" SkinID="lblskingen" Text='<%#Eval("User_IP_Address")%>'></asp:Label>
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
</asp:Content>
