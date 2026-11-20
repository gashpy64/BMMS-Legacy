<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="Followup.aspx.cs" Inherits="BMMS.Master.Followup" Title="Followup"
    MaintainScrollPositionOnPostback="true" %>

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
                                            <asp:ListItem Text="Pending" Value="0"></asp:ListItem>
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
                        <%-- Step UN6d: a role that can only read the followups (MD Secretariat) is told so above the list.
                             The wrapper is a floated row like the .divRow rows around it (wb-followup-row), so the line
                             stays below the filter rows --%>
                        <div class="wb-followup-row">
                            <p id="pFollowupReadOnly" runat="server" class="wb-dash-message" visible="false"></p>
                        </div>
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
                                    <%-- Step FU1: Status replaces the Is Confirmed tick. A Pending row of the Controller has the
                                         drop-down (Pending / Confirmed; Submit saves the rows changed to Confirmed); a Confirmed row
                                         is final: who and when, and for the Controller the Reopen button. The text is built and
                                         encoded in grvFollowup_RowDataBound --%>
                                    <asp:TemplateField HeaderText="Status">
                                        <ItemTemplate>
                                            <asp:Label ID="lblIsConfirmed" runat="server" Text='<%#Eval("IsConfirmed") %>' Visible="false"></asp:Label>
                                            <asp:DropDownList ID="ddlStatus" runat="server" CssClass="wb-followup-status-ddl" ToolTip="Status of this followup">
                                                <asp:ListItem Text="Pending" Value="0" Selected="True"></asp:ListItem>
                                                <asp:ListItem Text="Confirmed" Value="1"></asp:ListItem>
                                            </asp:DropDownList>
                                            <asp:Literal ID="litStatus" runat="server" Mode="PassThrough"></asp:Literal>
                                            <asp:Button ID="btnReopen" CssClass="button wb-followup-reopen-button" Text="Reopen" CommandArgument='<%#Eval("ActionItemId")%>'
                                                runat="server" CommandName="Reopen" ToolTip="Reopen this followup (a reason is asked)" />
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd wb-followup-status-cell" VerticalAlign="Middle" HorizontalAlign="Left"
                                            Width="220px" />
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
                        <div class="MyPopupContentInner wb-followup-popup">
                            <div class="formPanel">
                                <div class="divHeader">
                                    :: View Minute Actual Resolution</div>
                                <div class="divRow" style="text-align: center;">
                                    <bmms:RichTextEditor ID="ftxtActualResolution" runat="server" Width="600px" Height="200px" ReadOnly="true" Label="Actual Resolution" />
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
                        <div class="MyPopupContentInner wb-followup-popup">
                            <div class="formPanel">
                                <div class="divHeader">
                                    <asp:Literal ID="litActionTextTitle" runat="server" Text=":: Edit Action Text"></asp:Literal></div>
                                <div class="divRow" style="text-align: center;">
                                    <%-- Width 600px: the same width is in ".wb-followup-popup .wb-dash-message" (CSS/bmms-workbench.css); change both together --%>
                                    <bmms:RichTextEditor ID="ftxtActionText" runat="server" Width="600px" Height="200px" Label="Action Text" />
                                </div>
                                <%-- Step UN6d: the read-only line, or a save that failed, a busy server or a text that is too
                                     long (the page's message box lies under this panel). A floated row (wb-followup-row),
                                     so it sits under the editor's row, as wide as the editor --%>
                                <div class="wb-followup-row" aria-live="polite">
                                    <p id="pActionTextPanelMessage" runat="server" class="wb-dash-message" visible="false"></p>
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
            <%-- Step FU1: the Reopen panel, Controller only, one confirmed followup at once (never part of Submit) --%>
            <asp:Panel ID="pnlReopen" runat="server">
                <div class="MyPopupOuter">
                    <div class="MyPopupContent">
                        <div class="MyPopupContentInner wb-followup-popup">
                            <div class="formPanel">
                                <div class="divHeader">
                                    :: Reopen Followup</div>
                                <div class="wb-followup-row">
                                    <p id="pReopenItem" runat="server" class="wb-followup-reopen-item"></p>
                                </div>
                                <div class="wb-followup-row">
                                    <div class="wb-followup-reopen">
                                        <asp:Label ID="lblReopenReason" runat="server" AssociatedControlID="txtReopenReason" CssClass="Lable"
                                            Text="Reason for reopening :"></asp:Label>
                                        <span class="spanMandatory">*</span>
                                        <%-- Width: .wb-followup-reopen is 600px, as the Action Text editor (CSS/bmms-workbench.css) --%>
                                        <asp:TextBox ID="txtReopenReason" runat="server" TextMode="MultiLine" Rows="5" CssClass="wb-followup-reopen-text"></asp:TextBox>
                                        <span class="wb-followup-reopen-hint">At most 500 characters.</span>
                                    </div>
                                </div>
                                <%-- The check in the browser (a "<" that the server would refuse) and the server's messages:
                                     blank, too long, refused, failed --%>
                                <div class="wb-followup-row" aria-live="polite">
                                    <p id="pReopenCheck" class="wb-dash-message" role="alert" hidden="hidden"></p>
                                    <p id="pReopenPanelMessage" runat="server" class="wb-dash-message" visible="false"></p>
                                </div>
                                <div class="divRow" style="text-align: center;">
                                    <asp:Button ID="btnReopenSave" runat="server" CssClass="button" Text="Save" OnClick="btnReopenSave_Click" />
                                    <asp:Button ID="btnReopenCancel" runat="server" CssClass="button" Text="Cancel" OnClick="btnReopenCancel_Click" />
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

    <script type="text/javascript">
        // Step FU1 (decision D5): the server refuses a post with "<" followed by a letter, "!", "/" or "?", or with "&#"
        // (request validation), and the page would go to the error page. Checked here before the post; nothing is sent.
        function FollowupReopenCheck() {
            var box = document.getElementById("<%= txtReopenReason.ClientID %>");
            var line = document.getElementById("pReopenCheck");
            if (!box || !line) return true;
            if (/<[a-zA-Z!\/?]/.test(box.value) || /&#/.test(box.value)) {
                // Step FU2b (RA-2): one message only: the server's line of an earlier Save ("Enter the reason for
                // reopening.") is cleared
                var server = document.getElementById("<%= pReopenPanelMessage.ClientID %>");
                if (server) {
                    server.textContent = "";
                    server.style.display = "none";
                }
                line.textContent = "Remove the \"<\" or \"&#\" from the reason, then save again.";
                line.hidden = false;
                box.focus();
                return false;
            }
            line.textContent = "";
            line.hidden = true;
            return true;
        }
    </script>
</asp:Content>
