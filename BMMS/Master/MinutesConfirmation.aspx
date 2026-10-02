<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="MinutesConfirmation.aspx.cs" Inherits="BMMS.Master.MinutesConfirmation"
    Title="Minutes Confirmation" ValidateRequest="false" %>

<%@ Register Assembly="FreeTextBox" Namespace="FreeTextBoxControls" TagPrefix="FTB" %>
<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="formContent">
    <div class="formPanel">
        <div class="divHeader">
        :: Minutes Confirmation</div>
        <div class="divRowFixed"></div>
        <div class="divRow" style="height: 25px">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
        </div>
        <asp:Panel ID="pnlMinutesConfirm" runat="server">
            <div class="divRow">
                <div class="divRow">
                    <div class="divRowLeft">
                        Committee Name :
                    </div>
                    <div class="divRowRight">
                        <asp:DropDownList ID="ddlCommittee" runat="server" Width="150px" AutoPostBack="true"
                            OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                        </asp:DropDownList>
                        <span class="spanMandatory">*</span>
                    </div>
                </div>
                <div class="divRow">
                    <div class="divRowLeft">
                        Meeting No :
                    </div>
                    <div class="divRowRight">
                        <asp:DropDownList ID="ddlMeeting" runat="server" Width="150px" AutoPostBack="true">
                        </asp:DropDownList>
                        <span class="spanMandatory">*</span>
                        <br />
                        <br />
                        <br />
                        <asp:Button ID="btnConfirm" runat="server" CssClass="button" Text="Confirm" OnClick="btnConfirm_Click"
                            OnClientClick="return confirm('Do you want to Confirm this Meeting Minutes?');"  />
                        <asp:Button ID="btnCancel" runat="server" CssClass="button" Text="Cancel" OnClick="btnCancel_Click" />
                    </div>
                </div>
            </div>
        </asp:Panel>
    </div>
    </div>
</asp:Content>
