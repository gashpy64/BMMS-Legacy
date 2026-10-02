<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="Followup.aspx.cs" Inherits="BMMS.Master.Followup" Title="Followup"
    ValidateRequest="false" MaintainScrollPositionOnPostback="true" %>

<%@ Register Assembly="FreeTextBox" Namespace="FreeTextBoxControls" TagPrefix="FTB" %>
<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <div class="formContent">
                <div class="formPanel">
                    <div class="divHeader">
                        :: Followup</div>
                    <div class="divRowFixed">
                    </div>
                    <div class="divRow" style="height: 25px">
                        <div id="divErrLogin" runat="server" class="divErrorHide">
                            <span id="spanErrLogin" runat="server" class="lblError"></span>
                        </div>
                    </div>
                    <asp:Panel ID="pnlFollowupFilter" runat="server">
                        <div class="divRow">
                            <table cellspacing="12" cellpadding="0" border="0" width="100%">
                                <tr>
                                    <td class="Lable" style="width: 20%">
                                        Meeting Date From :
                                    </td>
                                    <td style="width: 30%">
                                        <table>
                                            <tr>
                                                <td>
                                                    <asp:TextBox ID="txtFromDate" runat="server" Width="80px" onfocus="this.blur();"
                                                        TabIndex="-1"></asp:TextBox>
                                                </td>
                                                <td>
                                                    <asp:ImageButton runat="Server" ID="imgFromDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                                </td>
                                                <td>
                                                    <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender1" runat="server"
                                                        TargetControlID="txtFromDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                                        PopupButtonID="imgFromDate">
                                                    </cc1:CalendarExtender>
                                                </td>
                                                <td>
                                                    to
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="txtToDate" runat="server" Width="80px" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                                                </td>
                                                <td>
                                                    <asp:ImageButton runat="Server" ID="imgToDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                                    <span class="spanMandatory">*</span>
                                                </td>
                                                <td>
                                                    <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender2" runat="server"
                                                        TargetControlID="txtToDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                                        PopupButtonID="imgToDate">
                                                    </cc1:CalendarExtender>
                                                </td>
                                            </tr>
                                        </table>
                                    </td>
                                    <td class="Lable" style="width: 15%">
                                        Committee Name :
                                    </td>
                                    <td style="width: 35%">
                                        <asp:DropDownList ID="ddlCommittee" runat="server" Width="300px" AutoPostBack="true"
                                            OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                                        </asp:DropDownList>
                                    </td>
                                </tr>
                                <tr>
                                    <td class="Lable">
                                        Meeting No. Search :
                                    </td>
                                    <td>
                                        <asp:RadioButtonList ID="rdoMeatingNoSearch" runat="server" RepeatDirection="Horizontal"
                                            AutoPostBack="true" OnSelectedIndexChanged="rdoMeatingNoSearch_SelectedIndexChanged">
                                            <asp:ListItem Text="Particular" Value="0" Selected="True"></asp:ListItem>
                                            <asp:ListItem Text="Between" Value="1"></asp:ListItem>
                                        </asp:RadioButtonList>
                                    </td>
                                    <td class="Lable">
                                        Department :
                                    </td>
                                    <td>
                                        <asp:DropDownList ID="ddlDepartment" runat="server" Width="300px">
                                        </asp:DropDownList>
                                    </td>
                                </tr>
                                <tr>
                                    <td class="Lable">
                                        Meeting No. :
                                    </td>
                                    <td>
                                        <asp:Panel ID="pnlMeetingNoParticular" runat="server">
                                            <asp:DropDownList ID="ddlMeetingNo" runat="server" Width="80px">
                                            </asp:DropDownList>
                                        </asp:Panel>
                                        <asp:Panel ID="pnlMeetingNoBetween" runat="server">
                                            <asp:DropDownList ID="ddlMeetingNoFrom" runat="server" Width="80px">
                                            </asp:DropDownList>
                                            <asp:Label ID="lblMeetingNo" runat="server" Text=" to "></asp:Label>
                                            <asp:DropDownList ID="ddlMeetingNoTo" runat="server" Width="80px">
                                            </asp:DropDownList>
                                        </asp:Panel>
                                    </td>
                                    <td class="Lable">
                                        Confirmed Status :
                                    </td>
                                    <td colspan="3">
                                        <asp:RadioButtonList ID="rdoConfirmStatus" runat="server" RepeatDirection="Horizontal">
                                            <asp:ListItem Text="Both" Value="-1" Selected="True"></asp:ListItem>
                                            <asp:ListItem Text="Confirmed" Value="1"></asp:ListItem>
                                            <asp:ListItem Text="Not Confirmed" Value="0"></asp:ListItem>
                                        </asp:RadioButtonList>
                                    </td>
                                </tr>
                            </table>
                        </div>
                        <div class="divRow">
                            <div class="divRowLeft">
                                <img src="../Images/spacer.gif" />
                            </div>
                            <div class="divRowRight">
                                <asp:Button ID="btnViewFollowup" runat="server" CssClass="button" Text="View" OnClick="btnViewFollowup_Click" />
                                <asp:Button ID="btnCancel" runat="server" CssClass="button" Text="Cancel" OnClick="btnCancel_Click" />
                            </div>
                        </div>
                    </asp:Panel>
                    <asp:Panel ID="pnlViewFollowup" runat="server">
                        <div class="divRow">
                            <asp:GridView ID="grvFollowup" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                                CssClass="contentTable1" AllowSorting="true" CellPadding="4" DataKeyNames="MinutesId"
                                Font-Names="Verdana, Arial, Helvetica, sans-serif" Font-Size="X-Small" ForeColor="#333333"
                                GridLines="Horizontal" Height="32px" Width="100%" OnRowDataBound="grvFollowup_RowDataBound"
                                OnSorting="grvRecord_Sorting" OnRowCommand="grvFollowup_RowCommand">
                                <HeaderStyle CssClass="contentTableHeader" HorizontalAlign="Center" Font-Bold="true" />
                                <Columns>
                                    <asp:TemplateField HeaderText="S.No.">
                                        <ItemTemplate>
                                            <%# Container.DataItemIndex+1 + "."%>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                            Width="10px" />
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Committee Name">
                                        <ItemTemplate>
                                            <asp:Label ID="lblCommitteeName" runat="server" Text='<%#Eval("CommitteeName") %>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" Width="150px" />
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Meeting No">
                                        <ItemTemplate>
                                            <asp:Label ID="lblMeetingNo" runat="server" Text='<%#Eval("MeetingNo") %>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Meeting Date">
                                        <ItemTemplate>
                                            <asp:Label ID="lblMeetingDate" runat="server" Text='<%#Eval("MeetingDate","{0:dd/MM/yyyy}") %>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" Width="100px" Height="35px" VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    
                                    <asp:TemplateField HeaderText="Agenda No.">
                                        <ItemTemplate>
                                            <asp:Label ID="lblAgendaNo" runat="server" Text='<%#Eval("AgendaNo") %>'></asp:Label>
                                            <asp:Label ID="lblMinutesId" runat="server" Text='<%#Eval("MinutesId") %>' Visible="false"></asp:Label>
                                            <asp:Label ID="lblAgendaId" runat="server" Text='<%#Eval("AgendaId") %>' Visible="false"></asp:Label>
                                            <asp:Label ID="lblActionItemId" runat="server" Text='<%#Eval("ActionItemId") %>'
                                                Visible="false"></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Subject No.">
                                        <ItemTemplate>
                                            <asp:Label ID="lblSubjectNo" runat="server" Text='<%#Eval("SubjectNo") %>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Decision">
                                        <ItemTemplate>
                                            <asp:Label ID="lblDecisionType" runat="server" Text='<%#Eval("DecisionTypeName") %>'
                                                Visible="true"></asp:Label>
                                            <asp:Label ID="lblDecisionTypeId" runat="server" Text='<%#Eval("DecisionTypeId") %>'
                                                Visible="false"></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    <%--<asp:TemplateField HeaderText="Due Date">
                                        <ItemTemplate>
                                            <asp:Label ID="lblDueDate" runat="server" Text='<%#Eval("DueDate", "{0:dd-MM-yyyy}") %>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Directions" Visible="false">
                                        <ItemTemplate>
                                            <asp:Button ID="btnDirections" CssClass="button" Text="View" CommandArgument='<%#Eval("ActionItemId")%>'
                                                runat="server" CommandName="ViewDirections" />
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                            Width="100px" />
                                    </asp:TemplateField>--%>
                                    <asp:TemplateField HeaderText="Actual Resolution">
                                        <ItemTemplate>
                                            <asp:Button ID="btnActualResolution" CssClass="button" Text="View" CommandArgument='<%#Eval("ActionItemId")%>'
                                                runat="server" CommandName="ViewActualResolution" />
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                            Width="100px" />
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Action Text">
                                        <ItemTemplate>
                                            <asp:Button ID="btnActionText" CssClass="button" Text="Edit" CommandArgument='<%#Eval("ActionItemId")%>'
                                                runat="server" CommandName="ViewActionText" />
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                            Width="100px" />
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Is Confirmed">
                                        <ItemTemplate>
                                            <asp:Label ID="lblIsConfirmed" runat="server" Text='<%#Eval("IsConfirmed") %>' Visible="false"></asp:Label>
                                            <asp:CheckBox ID="chkIsConfirmed" runat="server" />
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                            Width="100px" />
                                    </asp:TemplateField>
                                </Columns>
                                <EmptyDataTemplate>
                                    <div class="divNoRecord">
                                        <%#Session["NoRecord"].ToString()%>
                                    </div>
                                </EmptyDataTemplate>
                            </asp:GridView>
                        </div>
                        <div class="divRow" style="text-align: center">
                            <asp:Button ID="btnSubmit" runat="server" CssClass="button" Text="Submit" OnClick="btnSubmit_Click" />
                        </div>
                    </asp:Panel>
                </div>
            </div>
            <asp:Panel ID="pnlActualResolution" runat="server">
                <div class="MyPopupOuter">
                    <div class="MyPopupContent">
                        <div class="MyPopupContentInner">
                            <div class="formPanel">
                                <div class="divHeader">
                                    :: Edit Minute Actual Resolution</div>
                                <div class="divRow" style="text-align: center;">
                                    <FTB:FreeTextBox ID="ftxtActualResolution" runat="server" Width="600px" Height="200px"
                                        AllowHtmlMode="false" ShowTagPath="false" AutoGenerateToolbarsFromString="True"
                                        ButtonSet="Office2003" ToolbarLayout="Bold,Italic,Underline|JustifyLeft,JustifyRight,JustifyCenter,JustifyFull;BulletedList,NumberedList,Indent,Outdent"
                                        ToolbarStyleConfiguration="Office2003">
                                    </FTB:FreeTextBox>
                                </div>
                                <div class="divRow" style="text-align: center;">
                                    <asp:Button ID="btnActualResolutionCancel" runat="server" CssClass="button" Text="Cancel"
                                        OnClick="btnActualResolutionCancel_Click" />
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </asp:Panel>
            <asp:Panel ID="pnlActionText" runat="server">
                <div class="MyPopupOuter">
                    <div class="MyPopupContent">
                        <div class="MyPopupContentInner">
                            <div class="formPanel">
                                <div class="divHeader">
                                    :: Edit Action Text</div>
                                <div class="divRow" style="text-align: center;">
                                    <FTB:FreeTextBox ID="ftxtActionText" runat="server" Width="600px" Height="200px"
                                        AllowHtmlMode="false" ShowTagPath="false" AutoGenerateToolbarsFromString="True"
                                        ButtonSet="Office2003" ToolbarLayout="Bold,Italic,Underline|JustifyLeft,JustifyRight,JustifyCenter,JustifyFull;BulletedList,NumberedList,Indent,Outdent"
                                        ToolbarStyleConfiguration="Office2003">
                                    </FTB:FreeTextBox>
                                </div>
                                <div class="divRow" style="text-align: center;">
                                    <asp:Button ID="btnActionTextSave" runat="server" CssClass="button" Text="Save" OnClick="btnActionTextSave_Click" />
                                    <asp:Button ID="btnActionTextCancel" runat="server" CssClass="button" Text="Cancel"
                                        OnClick="btnActionTextCancel_Click" />
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </asp:Panel>
            <asp:HiddenField ID="hdnMinutesId" runat="server" />
            <asp:HiddenField ID="hdnAgendaId" runat="server" />
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
