<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="User.aspx.cs" Inherits="BMMS.Master.User" Title="Untitled Page" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="formContent">
    <div class="formPanel">
        <div class="divHeader">
        :: User Master</div>
        <div class="divRowFixed"></div> 
        <div class="divRow" style="height: 25px">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
        </div>
        <asp:Panel ID="pnlViewUser" runat="server">
            <div class="divRow" style="margin: auto; float: none; width: 700px;">
                <div class="divRow">
                    <asp:Button ID="btnAdd" runat="server" CssClass="button" Text="Add" OnClick="btnAdd_Click" />
                </div>
                <div class="divRow">
                    <asp:GridView ID="grvUser" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                        CssClass="contentTable1" AllowSorting="true" CellPadding="4" DataKeyNames="UserId"
                        Font-Names="Verdana, Arial, Helvetica, sans-serif" Font-Size="X-Small" ForeColor="#333333"
                        GridLines="Horizontal" Height="32px" Width="100%" OnRowDataBound="grvUser_RowDataBound"
                        OnSorting="grvRecord_Sorting" OnRowCommand="grvUser_RowCommand">
                        <HeaderStyle CssClass="contentTableHeader" HorizontalAlign="Center" Font-Bold="true" />
                        <Columns>
                            <asp:TemplateField HeaderText="S.No.">
                                <ItemTemplate>
                                    <%# Container.DataItemIndex+1 + "."%>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                    Width="10px" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="UserName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk2" runat="server" Text="User Name" CommandName="Sort" Style="color: White"
                                        CommandArgument="UserName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblEmployeName" runat="server" SkinID="lblskingen" Text='<%#Eval("UserName")%>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="DepartmentName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk3" runat="server" Text="Department Name" CommandName="Sort"
                                        Style="color: White" CommandArgument="DepartmentName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblDepartmentName" runat="server" SkinID="lblskingen" Text='<%#Eval("DepartmentName")%>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="DesignationName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk4" runat="server" Text="Designation Name" CommandName="Sort"
                                        Style="color: White" CommandArgument="DesignationName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblDesignationName" runat="server" SkinID="lblskingen" Text='<%#Eval("DesignationName")%>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="EmailId">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk5" runat="server" Text="Email Id" CommandName="Sort" Style="color: White"
                                        CommandArgument="EmailId"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblEmailId" runat="server" SkinID="lblskingen" Text='<%#Eval("EmailId")%>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="RoleName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk6" runat="server" Text="Role Name" CommandName="Sort" Style="color: White"
                                        CommandArgument="RoleName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblRoleName" runat="server" SkinID="lblskingen" Text='<%#Eval("RoleName")%>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="LoginName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk7" runat="server" Text="Login / User ID" CommandName="Sort"
                                        Style="color: White" CommandArgument="LoginName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblLoginName" runat="server" SkinID="lblskingen" Text='<%#Eval("LoginName")%>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnEdit" Width="18px" Height="18px" CssClass="buttonEdit" ToolTip="Edit"
                                        CommandArgument='<%#Eval("UserId")%>' runat="server" CommandName="EditRec" />
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                    Width="30px" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnDelete" Width="18px" Height="18px" CssClass="buttonDelete" ToolTip="Delete"
                                        CommandArgument='<%#Eval("UserId")%>' runat="server" CommandName="DeleteRec"
                                        OnClientClick="return confirm('Are you sure you want to delete this Record?');" />
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                    Width="30px" />
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
        </asp:Panel>
        <asp:Panel ID="pnlEditUser" runat="server">
            <div class="divRow">
                <div class="divRow">
                    <div class="divRowLeft">
                        <div class="divRowLeft">
                            User Name :
                        </div>
                        <div class="divRowRight">
                            <asp:TextBox ID="txtUserName" runat="server" Width="150px"></asp:TextBox>
                            <asp:HiddenField ID="hdnUserId" runat="server" />
                        </div>
                    </div>
                    <div class="divRowLeft">
                        <div class="divRowLeft">
                            Department :
                        </div>
                        <div class="divRowRight">
                            <asp:DropDownList ID="ddlDepartment" runat="server" Width="155px" AutoPostBack="True"
                                OnSelectedIndexChanged="ddlDepartment_SelectedIndexChanged">
                            </asp:DropDownList>
                            <span class="spanMandatory">*</span>
                        </div>
                    </div>
                </div>
                <div class="divRow">
                    <div class="divRowLeft">
                        <div class="divRowLeft">
                            Role :
                        </div>
                        <div class="divRowRight">
                            <asp:DropDownList ID="ddlRole" runat="server" Width="155px" AutoPostBack="True" OnSelectedIndexChanged="ddlRole_SelectedIndexChanged">
                            </asp:DropDownList>
                            <span class="spanMandatory">*</span>
                        </div>
                    </div>
                    <div class="divRowLeft">
                        <div class="divRowLeft">
                            Designation :
                        </div>
                        <div class="divRowRight">
                            <asp:DropDownList ID="ddlDesignation" runat="server" Width="155px">
                            </asp:DropDownList>
                            <span class="spanMandatory">*</span>
                        </div>
                    </div>
                </div>
                <div class="divRow">
                    <div class="divRowLeft">
                        <div class="divRowLeft">
                            Reporting Person :
                        </div>
                        <div class="divRowRight">
                            <asp:DropDownList ID="ddlManager" runat="server" Width="155px">
                            </asp:DropDownList>
                        </div>
                    </div>
                    <div class="divRowLeft">
                        <div class="divRowLeft">
                            EmailId :
                        </div>
                        <div class="divRowRight">
                            <asp:TextBox ID="txtEmailId" runat="server" Width="150px"></asp:TextBox>
                            <span class="spanMandatory">*</span>
                            <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender1" runat="server" TargetControlID="txtEmailId"
                                FilterMode="ValidChars" FilterType="Custom" ValidChars="abcdefghijklmnopqrstuvwxyz.@_">
                            </cc1:FilteredTextBoxExtender>
                        </div>
                    </div>
                </div>
                <div class="divRow">
                    <div class="divRowLeft">
                        <div class="divRowLeft">
                            User ID :
                        </div>
                        <div class="divRowRight">
                            <asp:TextBox ID="txtLoginName" runat="server" Width="150px"></asp:TextBox>
                            <span class="spanMandatory">*</span>
                            <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender2" runat="server" TargetControlID="txtLoginName"
                                InvalidChars=" .;" FilterMode="InvalidChars" FilterType="Custom">
                            </cc1:FilteredTextBoxExtender>
                        </div>
                    </div>
                    <div class="divRowLeft">
                        <div class="divRowLeft">
                        </div>
                        <div class="divRowRight">
                        </div>
                    </div>
                </div>
                <asp:Panel ID="pnlPwd" runat="server">
                    <div class="divRow">
                        <div class="divRowLeft">
                            <div class="divRow" style="height:30px;">
                                <div class="divRowLeft">
                                    Password :
                                </div>
                                <div class="divRowRight">
                                    <asp:TextBox ID="txtPassword" runat="server" TextMode="Password" Width="150px" oncopy="return false"
                                        oncut="return false" onpaste="return false" ></asp:TextBox>
                                    <span class="spanMandatory">*</span>
                                    <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender3" runat="server" TargetControlID="txtPassword"
                                        InvalidChars=" .,;" FilterMode="InvalidChars" FilterType="Custom">
                                    </cc1:FilteredTextBoxExtender>
                                    <cc1:PasswordStrength ID="PasswordStrength1" runat="server" TargetControlID="txtPassword"
                                        DisplayPosition="BelowLeft" StrengthIndicatorType="Text" PreferredPasswordLength="6"
                                        PrefixText="Strength:" TextCssClass="TextIndicator_TextBox1" MinimumNumericCharacters="1"
                                        MinimumSymbolCharacters="1" RequiresUpperAndLowerCaseCharacters="true" TextStrengthDescriptions=" Poor; Weak; Good; Strong; Excellent"
                                        TextStrengthDescriptionStyles="textIndicator_poor; textIndicator_weak; textIndicator_good; textIndicator_strong; textIndicator_excellent"
                                        HelpHandlePosition="AboveLeft" CalculationWeightings="25;25;15;35">
                                    </cc1:PasswordStrength>
                                </div>
                            </div>
                            <div class="divRow">
                                <div class="divRowLeft">
                                    Confirm Password :
                                </div>
                                <div class="divRowRight">
                                    <asp:TextBox ID="txtConfirmPassword" runat="server" TextMode="Password" Width="150px"
                                        oncopy="return false" oncut="return false" onpaste="return false" ></asp:TextBox>
                                    <span class="spanMandatory">*</span>
                                    <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender4" runat="server" TargetControlID="txtConfirmPassword"
                                        InvalidChars=" .,;" FilterMode="InvalidChars" FilterType="Custom">
                                    </cc1:FilteredTextBoxExtender>
                                </div>
                            </div>
                        </div>
                        <div class="divRowLeft" style="color: Black; text-align: left;margin-left:-50px; font-size:8pt;">
                            <ul style="margin-left:-20px; margin-top:-2px;">
                            <li>Password length minimum of 6 characters in length.</li>
                            <li>The password should contain combination of UpperCase, LowerCase, Number and Special
                            Character.</li>
                            </ul>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRowLeft">
                        </div>
                        <div class="divRowLeft">
                            <div class="divRowLeft">
                            </div>
                            <div class="divRowRight">
                            </div>
                        </div>
                    </div>
                </asp:Panel>
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
