<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="MinutesUpdate.aspx.cs" Inherits="BMMS.Master.MinutesUpdate" Title="Untitled Page"
    MaintainScrollPositionOnPostback="false" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <%-- Step A2b: card layout (bmms-forms.css). Layout only: every control ID, handler and visibility rule is as before. --%>
    <link href="../CSS/bmms-forms.css" rel="stylesheet" type="text/css" />
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <div class="wb-page bmms-form bmms-form-minutes">
                <div class="wb-breadcrumb">
                    Minutes<span class="wb-breadcrumb-sep">/</span>Update Minutes</div>
                <h1 class="wb-h1">
                    Update Minutes</h1>
                <div aria-live="polite">
                    <div id="divErrLogin" runat="server" class="divErrorHide">
                        <span id="spanErrLogin" runat="server" class="lblError"></span>
                    </div>
                </div>
                <asp:Panel ID="pnlMinutesFinalize" runat="server">
                    <div class="bmms-strip">
                        <div class="bmms-strip-item">
                            <label for="ctl00_ContentPlaceHolder1_ddlCommittee">
                                Committee Name</label>
                            <asp:DropDownList ID="ddlCommittee" runat="server" AutoPostBack="true"
                                OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                            </asp:DropDownList>
                        </div>
                        <div class="bmms-strip-item">
                            <label for="ctl00_ContentPlaceHolder1_ddlMeeting">
                                Meeting No</label>
                            <asp:DropDownList ID="ddlMeeting" runat="server" AutoPostBack="true">
                            </asp:DropDownList>
                        </div>
                        <div class="bmms-strip-action">
                            <asp:Button ID="btnUpdateMinutes" runat="server" CssClass="wb-btn" Text="Update Minutes"
                                OnClick="btnUpdateMinutes_Click" />
                        </div>
                    </div>
                </asp:Panel>
                <asp:Panel ID="pnlViewMinute" runat="server">
                    <div class="wb-card">
                        <h2 class="wb-card-header">
                            Decisions</h2>
                        <div class="wb-table-scroll">
                            <asp:GridView ID="grvMinutes" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                                CssClass="wb-table wb-table-wide" AllowSorting="true" DataKeyNames="MinutesId"
                                GridLines="None" OnRowDataBound="grvMinutes_RowDataBound"
                                OnSorting="grvRecord_Sorting" OnRowCommand="grvMinutes_RowCommand">
                                <Columns>
                                    <asp:TemplateField HeaderText="S.No.">
                                        <ItemTemplate>
                                            <%# Container.DataItemIndex+1 + "."%>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="wb-col-action" />
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Agenda No.">
                                        <ItemTemplate>
                                            <asp:Label ID="lblAgendaNo" runat="server" Text='<%#Eval("AgendaNo") %>'></asp:Label>
                                            <asp:Label ID="lblMinutesId" runat="server" Text='<%#Eval("MinutesId") %>' Visible="false"></asp:Label>
                                            <asp:Label ID="lblAgendaId" runat="server" Text='<%#Eval("AgendaId") %>' Visible="false"></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="wb-col-action" />
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Subject No.">
                                        <ItemTemplate>
                                            <asp:Label ID="lblSubjectNo" runat="server" Text='<%#Eval("SubjectNo") %>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="wb-col-action" />
                                    </asp:TemplateField>
                                    <asp:TemplateField HeaderText="Decision">
                                        <ItemTemplate>
                                            <asp:DropDownList ID="ddlDecisionType" runat="server" DataSource='<% #LoadDecisionType() %>'
                                                DataTextField="DecisionTypeName" DataValueField="DecisionTypeId" AutoPostBack="true"
                                                OnSelectedIndexChanged="ddlDecision_SelectedIndexChanged"
                                                aria-label='<%# "Decision, agenda " + Eval("AgendaNo") %>'>
                                            </asp:DropDownList>
                                            <asp:Label ID="lblDecisionTypeId" runat="server" Text='<%#Eval("DecisionTypeId") %>'
                                                Visible="false"></asp:Label>
                                        </ItemTemplate>
                                    </asp:TemplateField>
                                    <%-- Step UN6a: optional due date, only for a Followup decision (BMMS-Fix-MinutesDueDate-Step38.sql);
                                         enabled, filled and cleared in grvMinutes_RowDataBound and ddlDecision_SelectedIndexChanged --%>
                                    <asp:TemplateField HeaderText="Due Date">
                                        <ItemTemplate>
                                            <asp:TextBox ID="txtDueDate" runat="server" Width="110px" onfocus="this.blur();" TabIndex="-1"
                                                aria-label='<%# "Due date, agenda " + Eval("AgendaNo") %>'></asp:TextBox>
                                            <asp:ImageButton ID="imgCalendar" runat="server" ImageUrl="~/Images/Common/calendar.png"
                                                Width="18px" AlternateText="Choose the due date" />
                                            <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender1" runat="server"
                                                PopupButtonID="imgCalendar" TargetControlID="txtDueDate" Format="dd-MMM-yyyy" PopupPosition="BottomRight">
                                            </cc1:CalendarExtender>
                                            <input type="button" id="btnClearDueDate" runat="server" class="wb-link-btn" value="Clear"
                                                title="Clear the due date" />
                                        </ItemTemplate>
                                        <ItemStyle CssClass="wb-col-action" />
                                    </asp:TemplateField>
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
                                                aria-label='<%# "Agenda Short Text, agenda " + Eval("AgendaNo") %>'></asp:TextBox>
                                        </ItemTemplate>
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
                                            <asp:Button ID="btnEdit" CssClass="wb-btn wb-btn-secondary" Text="Edit" CommandArgument='<%#Eval("MinutesId")%>'
                                                runat="server" CommandName="EditActualResolution"
                                                aria-label='<%# "Edit Actual Resolution, agenda " + Eval("AgendaNo") %>' />
                                        </ItemTemplate>
                                        <ItemStyle CssClass="wb-col-action" />
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
                    <div class="wb-actions bmms-actionbar">
                        <asp:Button ID="btnSubmit" runat="server" CssClass="wb-btn" Text="Save minutes" OnClick="btnSubmit_Click" />
                        <asp:Button ID="btnCancel" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Cancel" OnClick="btnCancel_Click" />
                    </div>
                </asp:Panel>
            </div>
            <%-- The three panels below cannot be opened from the screen (their grid columns are Visible="false");
                 they are kept as they were --%>
            <asp:Panel ID="pnlDirections" runat="server">
                <div class="MyPopupOuter">
                    <div class="MyPopupContent">
                        <div class="formContent">
                            <div class="formPanel">
                                <div class="divHeader">
                                    :: Edit Minute Directions</div>
                                <div class="divRow" style="text-align: center;">
                                    <bmms:RichTextEditor ID="ftxtDirections" runat="server" Width="600px" Height="200px" Label="Directions" />
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
                                    <bmms:RichTextEditor ID="ftxtProposedResolution" runat="server" Width="600px" Height="200px" ReadOnly="true" Label="Proposed Resolution" />
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
            <%-- Actual Resolution: the same overlay as before (opened by the grid's Edit, closed by its own buttons),
                 shown as a centred card over the dimmed page --%>
            <asp:Panel ID="pnlActualResolution" runat="server">
                <div class="wb-page bmms-form bmms-form-minutes bmms-modal">
                    <div class="wb-card bmms-modal-card" role="dialog" aria-modal="true" aria-labelledby="bmmsActualResolutionTitle">
                        <h2 class="wb-card-header" id="bmmsActualResolutionTitle">
                            Edit Actual Resolution</h2>
                        <div class="wb-card-body">
                            <bmms:RichTextEditor ID="ftxtActualResolution" runat="server" Height="200px" Label="Actual Resolution" />
                            <p class="bmms-hint">
                                Saving the Actual Resolution also replaces the Proposed Resolution of this item.</p>
                            <div class="wb-actions bmms-modal-actions">
                                <asp:Button ID="btnActualResolutionSave" runat="server" CssClass="wb-btn" Text="Save resolution"
                                    OnClick="btnActualResolutionSave_Click" />
                                <asp:Button ID="btnActualResolutionCancel" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Close"
                                    OnClick="btnActualResolutionCancel_Click" />
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
