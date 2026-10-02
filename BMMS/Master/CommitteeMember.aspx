<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="CommitteeMember.aspx.cs" Inherits="BMMS.Master.CommitteeMember" MaintainScrollPositionOnPostback="true"
    Title="Untitled Page" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="formContent">
    <div class="formPanel">
        <div class="divHeader">
        :: Committee Member Tagging</div>
        <div class="divRowFixed"></div>
        <div class="divRow" style="height: 25px">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
        </div>
        <asp:Panel ID="pnlViewCommitteeMember" runat="server">
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
            </div>
            <div class="divRow" style="margin: auto; float: none; width: 900px;">
                <div class="divRow">
                    <asp:Button ID="btnAdd" runat="server" CssClass="button" Text="Add" OnClick="btnAdd_Click" />
                </div>
                <div class="divRow">
                    <asp:GridView ID="grvCommitteeMember" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                        CssClass="contentTable1" AllowSorting="true" CellPadding="4" DataKeyNames="CommitteeMemberId"
                        Font-Names="Verdana, Arial, Helvetica, sans-serif" Font-Size="X-Small" ForeColor="#333333" GridLines="Horizontal"
                        Height="32px" Width="100%" OnRowDataBound="grvCommitteeMember_RowDataBound" OnSorting="grvRecord_Sorting"
                        OnRowCommand="grvCommitteeMember_RowCommand">
                        <HeaderStyle CssClass="contentTableHeader" HorizontalAlign="Center" Font-Bold="true" />
                        <Columns>
                            <asp:TemplateField HeaderText="S.No.">
                                <ItemTemplate>
                                    <%# Container.DataItemIndex+1 + "."%>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                    Width="10px" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="CommitteeName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk1" runat="server" Text="Committee Name" CommandName="Sort"
                                        Style="color: White" CommandArgument="CommitteeName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblCommitteeMemberCode" SkinID="lblSkinGen" Text='<%#Eval("CommitteeName")%>'
                                        runat="server" />
                                    <asp:HiddenField ID="hdnCommitteeMemberCode" runat="server" />
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="MemberName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk2" runat="server" Text="Member Name" CommandName="Sort" Style="color: White"
                                        CommandArgument="MemberName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblMemberName" runat="server" SkinID="lblskingen" Text='<%#Eval("MemberName")%>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="DesignationName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnkDesignationName" runat="server" Text="Designation" CommandName="Sort" Style="color: White"
                                        CommandArgument="DesignationName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblDesignationName" runat="server" SkinID="lblskingen" Text='<%#Eval("DesignationName")%>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="MemberTypeName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk2" runat="server" Text="Member Type" CommandName="Sort" Style="color: White"
                                        CommandArgument="MemberTypeName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblMemberTypeName" runat="server" SkinID="lblskingen" Text='<%#Eval("MemberTypeName")%>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="AppointmentDate">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk3" runat="server" Text="Appointment Date" CommandName="Sort"
                                        Style="color: White" CommandArgument="AppointmentDate"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblAppointmentDate" runat="server" SkinID="lblskingen" Text='<%#Eval("AppointmentDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="CessationDate">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk4" runat="server" Text="Cessation Date" CommandName="Sort"
                                        Style="color: White" CommandArgument="CessationDate"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblCessationDate" runat="server" SkinID="lblskingen" Text='<%#Eval("CessationDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="IsFeeApplicable">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk5" runat="server" Text="Is Fee Applicable" CommandName="Sort"
                                        Style="color: White" CommandArgument="IsFeeApplicable"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblIsFeeApplicable" runat="server" SkinID="lblskingen" Text='<%#Eval("IsFeeApplicable").ToString() == "0" ? "No" : "Yes" %>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnEdit" Width="18px" Height="18px" CssClass="buttonEdit" ToolTip="Edit" CommandArgument='<%#Eval("CommitteeMemberId")%>'
                                        runat="server" CommandName="EditRec" />
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                    Width="30px" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnDelete" Width="18px" Height="18px" CssClass="buttonDelete"  ToolTip="Delete" CommandArgument='<%#Eval("CommitteeMemberId")%>'
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
        <asp:Panel ID="pnlEditCommitteeMember" runat="server">
            <div class="divRow">
                <div class="divRow" style="width: 70%;">
                    <div class="divRow">
                        <div class="divRow">
                            <div class="divRowLeft">
                                Committee Name :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtCommitteeName" runat="server" ReadOnly="true"></asp:TextBox>
                                <asp:HiddenField ID="hdnCommitteeId" runat="server" />
                                <asp:HiddenField ID="hdnCommitteeMemberId" runat="server" />
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRow">
                            <div class="divRowLeft">
                                Member Name :
                            </div>
                            <div class="divRowRight">
                                <asp:DropDownList ID="ddlMemberName" runat="server" Width="150px" AutoPostBack="true"
                                    OnSelectedIndexChanged="ddlMemberName_SelectedIndexChanged">
                                </asp:DropDownList>
                                <asp:TextBox ID="txtMemberName" runat="server" ReadOnly="true"></asp:TextBox>
                                <asp:HiddenField ID="hdnMemberId" runat="server" />
                                <span class="spanMandatory">*</span>
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRow">
                            <div class="divRowLeft">
                                Member Type :
                            </div>
                            <div class="divRowRight">
                                <asp:DropDownList ID="ddlMemberType" runat="server" Width="150px">
                                </asp:DropDownList>
                                <span class="spanMandatory">*</span>
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRow">
                            <div class="divRowLeft">
                                Appointment Date :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtAppointmentDate" runat="server" Width="100px" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                                <asp:ImageButton runat="Server" ID="imgAppointmentDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                <span class="spanMandatory">*</span>
                                <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender2" runat="server" TargetControlID="txtAppointmentDate"
                                    Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right" PopupButtonID="imgAppointmentDate">
                                </cc1:CalendarExtender>
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRow">
                            <div class="divRowLeft">
                                Cessation Date :
                            </div>
                            <div class="divRowRight">
                                <asp:Panel ID="pnlCessationDate" runat="server">
                                    <asp:TextBox ID="txtCessationDate" runat="server" Width="100px" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                                    <asp:ImageButton runat="Server" ID="imgCessationDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                    <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender1" runat="server" TargetControlID="txtCessationDate"
                                        Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right" PopupButtonID="imgCessationDate">
                                    </cc1:CalendarExtender>
                                </asp:Panel>
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRow">
                            <div class="divRowLeft">
                                Applicable Sitting Fees :
                            </div>
                            <div class="divRowRight">
                                <asp:RadioButtonList ID="rdoIsFeeApplicable" runat="server" AutoPostBack="True" OnSelectedIndexChanged="rdoIsFeeApplicable_SelectedIndexChanged"
                                    RepeatDirection="Horizontal">
                                    <asp:ListItem Text="Yes" Value="1"></asp:ListItem>
                                    <asp:ListItem Text="No" Value="0" Selected="True"></asp:ListItem>
                                </asp:RadioButtonList>
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRow">
                            <div class="divRowLeft">
                                Applicable Fee :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtApplicableFee" runat="server"></asp:TextBox>
                                <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender1" runat="server" TargetControlID="txtApplicableFee"
                                    FilterType="Custom" FilterMode="ValidChars" ValidChars="0123456789.">
                                </cc1:FilteredTextBoxExtender>
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
                <div class="divRow" style="width: 30%;">
                    <div class="divMemberDetails">
                        <asp:Literal ID="ltrlMemberDetails" runat="server"></asp:Literal>
                    </div>
                </div>
            </div>
        </asp:Panel>
    </div>
    </div>
</asp:Content>
