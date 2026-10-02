<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="ErrorPage.aspx.cs" Inherits="BMMS.Error.ErrorPage" Title="Untitled Page" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="formContent">
        <div class="formPanel">
            <asp:Panel ID="Panel1" runat="server" SkinID="pnlSkin">
                <div style="margin: auto; width: 75%; padding: 50px">
                    <div class="divRowAlignCenter">
                        <asp:Label ID="lblHeading" runat="server" SkinID="lblHeaderText" Text="Error"></asp:Label>
                    </div>
                    <div class="divRowSpace">
                    </div>
                    <div class="divRowSpace">
                    </div>
                    <div class="divRowAlignCenter">
                        <asp:Label ID="Label1" runat="server" Text="An unexpected error has raised!"></asp:Label>
                    </div>
                    <div class="divRowSpace">
                    </div>
                    <div class="divRowSpace">
                    </div>
                    <div class="divRowAlignCenter">
                        <asp:Label ID="lblMsg1" runat="server" Text="Please note down the below message and Forward it to the Technical Support Team"></asp:Label>
                    </div>
                    <div class="divRowSpace">
                    </div>
                    <div class="divRowSpace">
                    </div>
                    <div class="divRowAlignCenter" style="font-weight: bold;">
                        <asp:Label ID="lblError" runat="server" ForeColor="Red" Font-Names="Verdana, Arial, Helvetica, sans-serif"
                            Font-Size="medium" />
                    </div>
                    <div class="divRowSpace">
                    </div>
                    <div class="divRowSpace">
                    </div>
                    <div class="divRowSpace">
                    </div>
                    <div class="divRowAlignCenter">
                        <asp:Label ID="lblBack" runat="server" Text="Please Click Exit to go to the Previous Screen <br /> Or <br /> Click on the menu to go Through the next Transaction"
                            SkinID="lblErrorpage"></asp:Label>
                    </div>
                    <div class="divRowAlignCenter" style="color: #fee2c3; font-size: xx-small">
                        <asp:Label ID="lblErrDesc" runat="server" Text="-"></asp:Label>
                    </div>
                    <div class="divRowSpace">
                    </div>
                    <div class="divRowSpace">
                    </div>
                    <div class="divRowSpace">
                    </div>
                    <div class="divRowAlignCenter">
                        <asp:Button ID="btnExit" runat="server" CssClass="button" Text="Exit" OnClick="btnExit_Click" />
                    </div>
                    <div class="divRowSpace">
                    </div>
                    <div class="divRowSpace">
                    </div>
                </div>
            </asp:Panel>
        </div>
    </div>
</asp:Content>
