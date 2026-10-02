<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="MinutesUpdate.aspx.cs" Inherits="BMMS.Master.MinutesUpdate" Title="Untitled Page"
    ValidateRequest="false" MaintainScrollPositionOnPostback="false" %>

<%@ Register Assembly="FreeTextBox" Namespace="FreeTextBoxControls" TagPrefix="FTB" %>
<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <div class="formContent">
                <div class="formPanel">
                    <div class="divHeader">
                        :: Minutes</div>
                    <div class="divRowFixed">
                    </div>
                    <div class="divRow" style="height: 25px">
                        <div id="divErrLogin" runat="server" class="divErrorHide">
                            <span id="spanErrLogin" runat="server" class="lblError"></span>
                        </div>
                    </div>
                    <asp:Panel ID="pnlMinutesFinalize" runat="server">
                        <div class="divRow">
                            <div class="divRow">
                                <div class="divRowLeft">
                                    Committee Name :
                                </div>
                                <div class="divRowRight">
                                    <asp:DropDownList ID="ddlCommittee" runat="server" Width="150px" AutoPostBack="true"
                                        OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                                    </asp:DropDownList>
                                </div>
                            </div>
                            <div class="divRow">
                                <div class="divRowLeft">
                                    Meeting No :
                                </div>
                                <div class="divRowRight">
                                    <asp:DropDownList ID="ddlMeeting" runat="server" Width="150px" AutoPostBack="true">
                                    </asp:DropDownList>
                                    <br />
                                    <br />
                                    <asp:Button ID="btnUpdateMinutes" runat="server" CssClass="button" Text="Update Minutes"
                                        OnClick="btnUpdateMinutes_Click" />
                                    <asp:Button ID="btnCancel" runat="server" CssClass="button" Text="Cancel" OnClick="btnCancel_Click" />
                                </div>
                            </div>
                    </asp:Panel>
                    <asp:Panel ID="pnlViewMinute" runat="server">
                        <div class="divRow">
                            <asp:GridView ID="grvMinutes" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                                CssClass="contentTable1" AllowSorting="true" CellPadding="4" DataKeyNames="MinutesId"
                                Font-Names="Verdana, Arial, Helvetica, sans-serif" Font-Size="X-Small" ForeColor="#333333"
                                GridLines="Horizontal" Height="32px" Width="100%" OnRowDataBound="grvMinutes_RowDataBound"
                                OnSorting="grvRecord_Sorting" OnRowCommand="grvMinutes_RowCommand">
                                <HeaderStyle CssClass="contentTableHeader" HorizontalAlign="Center" Font-Bold="true" />
                                <Columns>
                                    <asp:TemplateField HeaderText="S.No.">
                                        <ItemTemplate>
                                            <%# Container.DataItemIndex+1 + "."%>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                            Width="10px" />
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Agenda No.">
                                        <ItemTemplate>
                                            <asp:Label ID="lblAgendaNo" runat="server" Text='<%#Eval("AgendaNo") %>'></asp:Label>
                                            <asp:Label ID="lblMinutesId" runat="server" Text='<%#Eval("MinutesId") %>' Visible="false"></asp:Label>
                                            <asp:Label ID="lblAgendaId" runat="server" Text='<%#Eval("AgendaId") %>' Visible="false"></asp:Label>
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
                                            <asp:DropDownList ID="ddlDecisionType" runat="server" DataSource='<% #LoadDecisionType() %>'
                                                DataTextField="DecisionTypeName" DataValueField="DecisionTypeId" AutoPostBack="true"
                                                OnSelectedIndexChanged="ddlDecision_SelectedIndexChanged">
                                            </asp:DropDownList>
                                            <asp:Label ID="lblDecisionTypeId" runat="server" Text='<%#Eval("DecisionTypeId") %>'
                                                Visible="false"></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    <%--<asp:TemplateField HeaderText="Due Date">
                                    <ItemTemplate>
                                        <asp:Label ID="lblDueDate" runat="server" Text='<%#Eval("DueDate") %>' Visible="false"></asp:Label>
                                        <asp:TextBox ID="txtDueDate" runat="server" Width="100px" onfocus="this.blur();"
                                            TabIndex="-1"></asp:TextBox>
                                        <asp:ImageButton ID="imgCalendar" runat="server" ImageUrl="~/Images/Common/calendar.png"
                                            Width="20px" Height="20px" />
                                        <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender1" runat="server"
                                            PopupButtonID="imgCalendar" TargetControlID="txtDueDate" Format="dd-MMM-yyyy">
                                        </cc1:CalendarExtender>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>--%>
                                    <asp:TemplateField HeaderText="Directions" Visible="false">
                                        <ItemTemplate>
                                            <asp:Button ID="btnDirections" CssClass="button" Text="Add" CommandArgument='<%#Eval("MinutesId")%>'
                                                runat="server" CommandName="AddDirections" />
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                            Width="100px" />
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Agenda Short Text">
                                        <ItemTemplate>
                                            <asp:Button ID="btnShortText" CssClass="button" Text="View" CommandArgument='<%#Eval("AgendaId")%>'
                                                runat="server" CommandName="ViewShortText" Visible="false" />
                                            <asp:TextBox ID="txtShortText" runat="server" Text='<%#Eval("ShortText")%>' TextMode="MultiLine"
                                                Style="width: 450px; height: 50px;"></asp:TextBox>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                            Width="100px" />
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Proposed Resolution" Visible="false">
                                        <ItemTemplate>
                                            <asp:Button ID="btnView" CssClass="button" Text="View" CommandArgument='<%#Eval("MinutesId")%>'
                                                runat="server" CommandName="ViewProposedResolution" />
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                            Width="100px" />
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Actual Resolution">
                                        <ItemTemplate>
                                            <asp:Button ID="btnEdit" CssClass="button" Text="Edit" CommandArgument='<%#Eval("MinutesId")%>'
                                                runat="server" CommandName="EditActualResolution" />
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
            <asp:Panel ID="pnlDirections" runat="server">
                <div class="MyPopupOuter">
                    <div class="MyPopupContent">
                        <div class="formContent">
                            <div class="formPanel">
                                <div class="divHeader">
                                    :: Edit Minute Directions</div>
                                <div class="divRow" style="text-align: center;">
                                    <FTB:FreeTextBox ID="ftxtDirections" runat="server" Width="600px" Height="200px"
                                        AllowHtmlMode="false" ShowTagPath="false" AutoGenerateToolbarsFromString="True"
                                        ButtonSet="Office2003" ToolbarLayout="Bold,Italic,Underline|JustifyLeft,JustifyRight,JustifyCenter,JustifyFull;BulletedList,NumberedList,Indent,Outdent"
                                        ToolbarStyleConfiguration="Office2003">
                                    </FTB:FreeTextBox>
                                </div>
                                <div class="divRow" style="text-align: center;">
                                    <asp:Button ID="btnDirectionsSave" runat="server" CssClass="button" Text="Save" OnClick="btnDirectionsSave_Click" />
                                    <asp:Button ID="btnDirectionsCancel" runat="server" CssClass="button" Text="Cancel"
                                        OnClick="btnDirectionsCancel_Click" />
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </asp:Panel>
            <asp:Panel ID="pnlShortText" runat="server">
                <div class="MyPopupOuter">
                    <div class="MyPopupContent">
                        <div class="formContent">
                            <div class="formPanel">
                                <div class="divHeader">
                                    :: Edit Agenda Short Text</div>
                                <div class="divRow" style="text-align: center;">
                                    <%--<FTB:FreeTextBox ID="ftxtShortText" runat="server" Width="600px" Height="200px"
                                    AllowHtmlMode="false" ShowTagPath="false"
                                    AutoGenerateToolbarsFromString="True" ButtonSet="Office2003" 
                                    ToolbarLayout="Bold,Italic,Underline|JustifyLeft,JustifyRight,JustifyCenter,JustifyFull;BulletedList,NumberedList,Indent,Outdent"
                                    ToolbarStyleConfiguration="Office2003">
                                </FTB:FreeTextBox>--%>
                                    <asp:TextBox ID="txtShortText" runat="server" ReadOnly="false" TextMode="MultiLine"
                                        Height="100px" Width="600px"></asp:TextBox>
                                </div>
                                <div class="divRow" style="text-align: center;">
                                    <asp:Button ID="btnShortTextSave" runat="server" CssClass="button" Text="Save" OnClick="btnShortTextSave_Click" />
                                    <asp:Button ID="btnShortTextCancel" runat="server" CssClass="button" Text="Cancel"
                                        OnClick="btnShortTextCancel_Click" />
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </asp:Panel>
            <asp:Panel ID="pnlProposedResolution" runat="server">
                <div class="MyPopupOuter">
                    <div class="MyPopupContent">
                        <div class="formContent">
                            <div class="formPanel">
                                <div class="divHeader">
                                    :: View Proposed Resolution</div>
                                <div class="divRow" style="text-align: center;">
                                    <FTB:FreeTextBox ID="ftxtProposedResolution" runat="server" Height="200px" AllowHtmlMode="false"
                                        ShowTagPath="false" AutoGenerateToolbarsFromString="True" ButtonSet="Office2003"
                                        ToolbarLayout="Bold,Italic,Underline|JustifyLeft,JustifyRight,JustifyCenter,JustifyFull;BulletedList,NumberedList,Indent,Outdent"
                                        ToolbarStyleConfiguration="Office2003">
                                    </FTB:FreeTextBox>
                                </div>
                                <div class="divRow" style="text-align: center;">
                                    <asp:Button ID="btnProposedResolutionCancel" runat="server" CssClass="button" Text="Cancel"
                                        OnClick="btnProposedResolutionCancel_Click" />
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </asp:Panel>
            <asp:Panel ID="pnlActualResolution" runat="server">
                <div class="MyPopupOuter">
                    <div class="MyPopupContent">
                        <div class="formContent">
                            <div class="formPanel">
                                <div class="divHeader">
                                    :: Edit Actual Resolution</div>
                                <div class="divRow" style="text-align: center;">
                                    <FTB:FreeTextBox ID="ftxtActualResolution" runat="server" Width="600px" Height="200px"
                                        AllowHtmlMode="false" ShowTagPath="false" AutoGenerateToolbarsFromString="True"
                                        ButtonSet="Office2003" ToolbarLayout="Bold,Italic,Underline|JustifyLeft,JustifyRight,JustifyCenter,JustifyFull;BulletedList,NumberedList,Indent,Outdent"
                                        ToolbarStyleConfiguration="Office2003">
                                    </FTB:FreeTextBox>
                                </div>
                                <div class="divRow" style="text-align: center;">
                                    <asp:Button ID="btnActualResolutionSave" runat="server" CssClass="button" Text="Save"
                                        OnClick="btnActualResolutionSave_Click" />
                                    <asp:Button ID="btnActualResolutionCancel" runat="server" CssClass="button" Text="Cancel"
                                        OnClick="btnActualResolutionCancel_Click" />
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
