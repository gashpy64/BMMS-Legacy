<%@ Page Language="C#" MasterPageFile="~/MasterPage/MainNoMenu.Master" AutoEventWireup="true"
    Codebehind="ChangePasswordFirst.aspx.cs" Inherits="BMMS.ChangePasswordFirst" Title="Change Password"
    ValidateRequest="false" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">

    <div class="formContent">
    <div class="formPanel">
    <div class="divHeader">
        :: Change Password</div>
        <div class="divRowFixed"></div>
        <asp:Panel ID="pnlPwd" runat="server">
            <div class="divRow">
                <div class="divRowError" style="height: 35px;">
                    <div id="divErrLogin" runat="server" class="divErrorHide">
                        <span id="spanErrLogin" runat="server" class="lblError"></span>
                    </div>
                </div>
            </div>
            <div class="divRow" style="height: 30px;">
                <div class="divRowLeft">
                    Old Password :
                </div>
                <div class="divRowRight">
                    <asp:TextBox ID="txtOldPassword" runat="server" TextMode="Password" Width="150px"
                        oncopy="return false" oncut="return false" onpaste="return false"></asp:TextBox>
                    <span class="spanMandatory">*</span>
                    <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender3" runat="server" TargetControlID="txtOldPassword"
                        InvalidChars=" .,;" FilterMode="InvalidChars" FilterType="Custom">
                    </cc1:FilteredTextBoxExtender>
                </div>
            </div>
            <div class="divRow" style="height: 30px;">
                <div class="divRowLeft">
                    New Password :
                </div>
                <div class="divRowRight">
                    <asp:TextBox ID="txtNewPassword" runat="server" TextMode="Password" Width="150px"
                        oncopy="return false" oncut="return false" onpaste="return false"></asp:TextBox>
                    <span class="spanMandatory">*</span>
                    <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender1" runat="server" TargetControlID="txtNewPassword"
                        InvalidChars=" .,;" FilterMode="InvalidChars" FilterType="Custom">
                    </cc1:FilteredTextBoxExtender>
                    <cc1:PasswordStrength ID="PasswordStrength2" runat="server" TargetControlID="txtNewPassword"
                        DisplayPosition="BelowLeft" StrengthIndicatorType="Text" PreferredPasswordLength="6"
                        PrefixText="Strength:" TextCssClass="TextIndicator_TextBox1" MinimumNumericCharacters="1"
                        MinimumSymbolCharacters="1" RequiresUpperAndLowerCaseCharacters="true" TextStrengthDescriptions=" Poor; Weak; Good; Strong; Excellent"
                        TextStrengthDescriptionStyles="textIndicator_poor; textIndicator_weak; textIndicator_good; textIndicator_strong; textIndicator_excellent"
                        HelpHandlePosition="AboveLeft" CalculationWeightings="25;25;15;35">
                    </cc1:PasswordStrength>
                </div>
            </div>
            <div class="divRow" style="height: 30px;">
                <div class="divRowLeft">
                    Confirm Password :
                </div>
                <div class="divRowRight">
                    <asp:TextBox ID="txtConfirmPassword" runat="server" TextMode="Password" Width="150px"
                        oncopy="return false" oncut="return false" onpaste="return false"></asp:TextBox>
                    <span class="spanMandatory">*</span>
                    <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender4" runat="server" TargetControlID="txtConfirmPassword"
                        InvalidChars=" .,;" FilterMode="InvalidChars" FilterType="Custom">
                    </cc1:FilteredTextBoxExtender>
                    <div class="divRow" style="color: Black; text-align: left; margin-left: -25px; font-size: 8pt;">
                        <ul style="">
                            <li>Password length minimum of 6 characters in length.</li>
                            <li>The password should contain combination of UpperCase, LowerCase, Number and Special
                                Character.</li>
                        </ul>
                    </div>
                    <div style="text-align: left; padding-top: 100px;">
                        <asp:Button ID="btnChangePwd" runat="server" Text="Submit" CssClass="button"
                            OnClick="btnChangePwd_Click" />
                    </div>
                </div>
            </div>
        </asp:Panel>
    </div>
    </div>
</asp:Content>
