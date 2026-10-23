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
                    <%-- Fixed text only (step E2): no exception message, nothing taken from the address --%>
                    <div class="divRowAlignCenter">
                        <asp:Label ID="Label1" runat="server" Text="This action could not be completed because of an error on the server. The error is in the error log. Go back, then check what was saved before you try again."></asp:Label>
                    </div>
                    <div class="divRowSpace">
                    </div>
                    <div class="divRowSpace">
                    </div>
                    <div class="divRowAlignCenter">
                        <asp:Label ID="lblBack" runat="server" Text="Use Exit to return to the previous page."
                            SkinID="lblErrorpage"></asp:Label>
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
