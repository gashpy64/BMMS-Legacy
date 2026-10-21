<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="ResetDatabase.aspx.cs" Inherits="BMMS.Master.ResetDatabase" Title="ResetDatabase"
    ValidateRequest="true" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <asp:UpdateProgress ID="UpdateProgress1" runat="server">
                <ProgressTemplate>
                    <div class="wb-progress-overlay">
                        <div class="wb-progress-box" role="status">
                            <strong>Reset in progress, please wait.</strong><br />
                            Resetting the database can take a few minutes. Do not close or reload this page;
                            the sign-in page opens when the reset is done.</div>
                    </div>
                </ProgressTemplate>
            </asp:UpdateProgress>
            <div class="wb-page">
                <div class="wb-breadcrumb">
                    Utilities<span class="wb-breadcrumb-sep">/</span>Reset Database</div>
                <h1 class="wb-h1">
                    Reset Database</h1>
                <div aria-live="polite">
                    <div id="divErrLogin" runat="server" class="divErrorHide">
                        <span id="spanErrLogin" runat="server" class="lblError"></span>
                    </div>
                </div>
                <div class="wb-card">
                    <div class="wb-card-header">
                        What a reset does</div>
                    <div class="wb-card-body">
                        <p class="wb-help">
                            Permanently deletes every committee, meeting, agenda item, minute, action item, alert,
                            member, user, role and master record, and the login, backup, mail and change audit, in
                            database <strong><asp:Literal ID="litDatabaseName" runat="server"></asp:Literal></strong>.
                            It then re-creates the default data: the four default users, the roles, departments,
                            designations, member, decision and subject types, and the two default committees.</p>
                        <p class="wb-help">
                            Kept: the organisation settings and logo, and the other system settings.</p>
                        <p class="wb-help">
                            Afterwards you are signed out. Sign in as <strong>admin</strong> with the default
                            password; you will be asked to choose a new one at once.</p>
                        <p class="wb-help">
                            If anything goes wrong during the reset, nothing is changed.</p>
                    </div>
                </div>
                <div class="wb-card">
                    <div class="wb-card-header">
                        Files that a reset does not remove</div>
                    <div class="wb-card-body">
                        <p class="wb-help">
                            Uploaded files stay on the server. After a reset, agenda numbers and member codes start
                            again, so a new upload with the same number or code and file name replaces an old file.
                            Remove these files separately if they must go.</p>
                        <div class="wb-table-scroll">
                            <asp:GridView ID="grvFiles" runat="server" AutoGenerateColumns="False" CssClass="wb-table"
                                GridLines="None">
                                <Columns>
                                    <asp:BoundField DataField="Folder" HeaderText="Folder" />
                                    <asp:BoundField DataField="Files" HeaderText="Files" />
                                </Columns>
                            </asp:GridView>
                        </div>
                    </div>
                </div>
                <div class="wb-card">
                    <div class="wb-card-header">
                        Confirm</div>
                    <div class="wb-card-body">
                        <div class="wb-row">
                            <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtConfirmDatabaseName">
                                Type the database name</label>
                            <div class="wb-field">
                                <asp:TextBox ID="txtConfirmDatabaseName" runat="server" MaxLength="128"
                                    autocomplete="off"></asp:TextBox>
                                <span class="wb-help">The name shown above; capital letters do not matter</span>
                            </div>
                        </div>
                        <div class="wb-actions">
                            <asp:Button ID="btnResetDatabase" runat="server" Text="Reset Database" CssClass="wb-btn"
                                OnClick="btnResetDatabase_Click" />
                        </div>
                    </div>
                </div>
            </div>
        </ContentTemplate>
    </asp:UpdatePanel>

    <script type="text/javascript">
        function ResetDatabaseShowMessage(text) {
            document.getElementById("<%= divErrLogin.ClientID %>").className = "divError";
            document.getElementById("<%= spanErrLogin.ClientID %>").innerHTML = text;
        }

        // Reset Database button: the typed name must be the database name shown on the page (trimmed,
        // capital letters do not matter) before the dialog opens; otherwise nothing is sent to the server.
        function ResetDatabaseConfirm(databaseName, confirmText) {
            var typed = document.getElementById("<%= txtConfirmDatabaseName.ClientID %>").value.replace(/^\s+|\s+$/g, "");

            if (typed.toLowerCase() != databaseName.toLowerCase()) {
                ResetDatabaseShowMessage("The name you typed is not the name of this database. Nothing was changed.");
                return false;
            }

            return confirm(confirmText);
        }

        // A reset request that fails or gets no answer in time is shown on the page, not only in the
        // browser console. The reset itself may still have finished on the server.
        Sys.Application.add_init(function () {
            Sys.WebForms.PageRequestManager.getInstance().add_endRequest(function (sender, args) {
                if (args.get_error() == null)
                    return;

                args.set_errorHandled(true);
                ResetDatabaseShowMessage("The page got no answer from the server. The reset may have finished: sign in again as admin to check.");
            });
        });
    </script>
</asp:Content>
