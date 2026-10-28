<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="SystemSettings.aspx.cs" Inherits="BMMS.Master.SystemSettings" Title="System Settings" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="wb-page">
        <div class="wb-breadcrumb">
            Utilities<span class="wb-breadcrumb-sep">/</span>System Settings</div>
        <h1 class="wb-h1">
            System Settings</h1>
        <div aria-live="polite">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
            <div id="divOrgNotSet" runat="server" class="divError" visible="false">
                <span class="lblError">Organisation details are not set. Notices, minutes, reports and certificates
                    print no organisation name or address until you fill them in below.</span>
            </div>
        </div>
        <div class="wb-card">
            <div class="wb-card-header">
                Agenda</div>
            <div class="wb-card-body">
                <div class="wb-row">
                    <div class="wb-field">
                        <asp:CheckBox ID="chkAgendaControllerBypass" runat="server"
                            Text="Controller can add, edit and delete agenda items after the agenda is finalized" />
                    </div>
                </div>
                <p class="wb-help">
                    Applies until the minutes are finalized. Default: on.
                    <asp:Literal ID="litLastChanged" runat="server"></asp:Literal></p>
                <div class="wb-actions">
                    <asp:Button ID="btnSave" runat="server" CssClass="wb-btn" Text="Save" OnClick="btnSave_Click" />
                    <asp:Button ID="btnCancel" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Cancel"
                        OnClick="btnCancel_Click" />
                </div>
            </div>
        </div>
        <div class="wb-card">
            <div class="wb-card-header">
                Organisation details (printed on notices, minutes, reports and certificates)</div>
            <div class="wb-card-body">
                <p class="wb-help">
                    An empty field is left out of the printed output. Letters, digits and the usual punctuation
                    (Windows-1252 characters) only.</p>
                <div class="wb-row">
                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtOrganisationName">
                        Organisation name</label>
                    <div class="wb-field">
                        <asp:TextBox ID="txtOrganisationName" runat="server" MaxLength="150"></asp:TextBox>
                        <span class="wb-help">Legal name, e.g. Example Company Limited</span>
                    </div>
                </div>
                <div class="wb-row">
                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtOrganisationShortName">
                        Short name</label>
                    <div class="wb-field">
                        <asp:TextBox ID="txtOrganisationShortName" runat="server" MaxLength="100"></asp:TextBox>
                        <span class="wb-help">Mail headers; empty: the organisation name</span>
                    </div>
                </div>
                <div class="wb-row">
                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtOrganisationTerm">
                        Organisation term</label>
                    <div class="wb-field wb-field-short">
                        <asp:TextBox ID="txtOrganisationTerm" runat="server" MaxLength="30"></asp:TextBox>
                        <span class="wb-help">As in "the Company's Board"; letters only; empty: Company</span>
                    </div>
                </div>
                <div class="wb-row">
                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtCertificateSignOff">
                        Certificate sign-off</label>
                    <div class="wb-field">
                        <asp:TextBox ID="txtCertificateSignOff" runat="server" MaxLength="150"></asp:TextBox>
                        <span class="wb-help">The text after "For", e.g. Example Company Ltd.,; empty: the organisation name</span>
                    </div>
                </div>
                <div class="wb-row">
                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtRegisteredOfficeLabel">
                        Office label</label>
                    <div class="wb-field">
                        <asp:TextBox ID="txtRegisteredOfficeLabel" runat="server" MaxLength="60"></asp:TextBox>
                        <span class="wb-help">e.g. Regd. &amp; Admin. Office</span>
                    </div>
                </div>
                <div class="wb-row">
                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtRegisteredOfficeLine1">
                        Office address line 1</label>
                    <div class="wb-field">
                        <asp:TextBox ID="txtRegisteredOfficeLine1" runat="server" MaxLength="100"></asp:TextBox>
                        <span class="wb-help">Street, e.g. 12 Sample Road</span>
                    </div>
                </div>
                <div class="wb-row">
                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtRegisteredOfficeLine2">
                        Office address line 2</label>
                    <div class="wb-field">
                        <asp:TextBox ID="txtRegisteredOfficeLine2" runat="server" MaxLength="100"></asp:TextBox>
                        <span class="wb-help">Locality</span>
                    </div>
                </div>
                <div class="wb-row">
                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtRegisteredOfficeCity">
                        City</label>
                    <div class="wb-field">
                        <asp:TextBox ID="txtRegisteredOfficeCity" runat="server" MaxLength="60"></asp:TextBox>
                        <span class="wb-help">Also the place line of the agenda summary</span>
                    </div>
                </div>
                <div class="wb-row">
                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtRegisteredOfficePinCode">
                        PIN code</label>
                    <div class="wb-field wb-field-short">
                        <asp:TextBox ID="txtRegisteredOfficePinCode" runat="server" MaxLength="12"></asp:TextBox>
                        <span class="wb-help">Digits, spaces and hyphens</span>
                    </div>
                </div>
                <div class="wb-row">
                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtOrganisationPhone">
                        Phone</label>
                    <div class="wb-field">
                        <asp:TextBox ID="txtOrganisationPhone" runat="server" MaxLength="60"></asp:TextBox>
                        <span class="wb-help">Certificate footer; digits, spaces and + - ( ) / ,</span>
                    </div>
                </div>
                <div class="wb-row">
                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtOrganisationFax">
                        Fax</label>
                    <div class="wb-field">
                        <asp:TextBox ID="txtOrganisationFax" runat="server" MaxLength="60"></asp:TextBox>
                    </div>
                </div>
                <div class="wb-row">
                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtOrganisationEmail">
                        E-mail</label>
                    <div class="wb-field">
                        <asp:TextBox ID="txtOrganisationEmail" runat="server" MaxLength="100"></asp:TextBox>
                        <span class="wb-help">Certificate footer; one address</span>
                    </div>
                </div>
                <p class="wb-help">
                    <asp:Literal ID="litOrgLastChanged" runat="server"></asp:Literal></p>
                <div class="wb-actions">
                    <asp:Button ID="btnSaveOrganisation" runat="server" CssClass="wb-btn" Text="Save organisation details"
                        OnClick="btnSaveOrganisation_Click" />
                </div>
            </div>
        </div>
        <div class="wb-card">
            <div class="wb-card-header">
                Organisation logo (printed at the top of PDFs and reports)</div>
            <div class="wb-card-body">
                <div class="wb-row">
                    <div class="wb-label">
                        Current logo</div>
                    <div class="wb-field">
                        <asp:Image ID="imgLogo" runat="server" AlternateText="Organisation logo" Visible="false" />
                        <asp:Literal ID="litNoLogo" runat="server" Text="No logo is set: printed output shows the organisation name in its place."></asp:Literal>
                    </div>
                </div>
                <div class="wb-row">
                    <label class="wb-label" for="ctl00_ContentPlaceHolder1_fuLogo">
                        New logo</label>
                    <div class="wb-field">
                        <asp:FileUpload ID="fuLogo" runat="server" accept=".png,.jpg,.jpeg,.gif" />
                    </div>
                </div>
                <p class="wb-help">
                    PNG, JPEG or GIF, at most 500 KB and 1000 x 300 pixels. It is stored as a PNG.</p>
                <div class="wb-actions">
                    <asp:Button ID="btnUploadLogo" runat="server" CssClass="wb-btn" Text="Upload logo" OnClick="btnUploadLogo_Click" />
                    <asp:Button ID="btnRemoveLogo" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Remove logo"
                        OnClick="btnRemoveLogo_Click" OnClientClick="return confirm('Remove the organisation logo?');" />
                </div>
            </div>
        </div>
    </div>
</asp:Content>
