<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="Agenda.aspx.cs" Inherits="BMMS.Master.Agenda" Title="Untitled Page"
    MaintainScrollPositionOnPostback="true" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <%-- Step A2b: card layout (bmms-forms.css). Layout only: every control ID, handler and visibility rule is as before. --%>
    <link href="../CSS/bmms-forms.css" rel="stylesheet" type="text/css" />

    <script language="javascript" type="text/javascript">
    function UploadClick(btnUploadId)
	{
		document.getElementById(btnUploadId).click();
	}
    </script>

    <div id="divProgress" class="divProgress" style="visibility: hidden;">
        <div class="divProgressBackground">
        </div>
        <div class="divProgressImg">
            Loading ...</div>
    </div>
    <div class="wb-page bmms-form bmms-form-agenda">
        <div class="wb-breadcrumb">
            Agenda<span class="wb-breadcrumb-sep">/</span>Agenda Entry</div>
        <h1 class="wb-h1">
            Agenda Entry</h1>
        <div aria-live="polite">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
        </div>

        <%-- List screen: choose the committee and meeting, Add, and the items of the meeting --%>
        <asp:Panel ID="pnlViewAgenda" runat="server">
            <div class="bmms-strip">
                <div class="bmms-strip-item">
                    <label for="ctl00_ContentPlaceHolder1_ddlCommittee">
                        Committee Name <span class="wb-req">*</span></label>
                    <asp:DropDownList ID="ddlCommittee" runat="server" AutoPostBack="true"
                        OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                    </asp:DropDownList>
                    <asp:Label ID="lblNextScheduledMeeting" runat="server" Text="-" Visible="false"></asp:Label>
                </div>
                <div class="bmms-strip-item">
                    <label for="ctl00_ContentPlaceHolder1_ddlMeeting">
                        Meeting No <span class="wb-req">*</span></label>
                    <%--<asp:TextBox ID="txtMeeting" runat="server" Text="-" Enabled="false"></asp:TextBox>
                    <asp:HiddenField ID="hdnSearchMeetingId" runat="server" />--%>
                    <asp:DropDownList ID="ddlMeeting" runat="server" AutoPostBack="true"
                        OnSelectedIndexChanged="ddlMeeting_SelectedIndexChanged" Enabled="true">
                    </asp:DropDownList>
                </div>
                <div class="bmms-strip-action">
                    <asp:Button ID="btnAdd" runat="server" CssClass="wb-btn" Text="Add" OnClick="btnAdd_Click" />
                </div>
            </div>
            <div class="wb-card">
                <div class="wb-card-header">
                    Agenda items in this meeting</div>
                <%-- Step C2: the list of a User holds the items they entered; the list of a Manager the items of the
                     Manager's department and the items the Manager entered (spr_GetAgendaByMeetingIdDeptId,
                     BMMS-Fix-ManagerDepartment-Step33.sql). The Controller sees every item and no line. --%>
                <%if (Session["RoleCode"].ToString() == "user")
                  { %>
                <p class="bmms-card-note">
                    Items you entered.</p>
                <%}
                  else if (Session["RoleCode"].ToString() == "manager")
                  { %>
                <p class="bmms-card-note">
                    Items of your department.</p>
                <%} %>
                <div class="wb-table-scroll">
                    <asp:GridView ID="grvAgenda" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                        CssClass="wb-table wb-table-wide" AllowSorting="true" DataKeyNames="AgendaId"
                        GridLines="None" OnRowDataBound="grvAgenda_RowDataBound"
                        OnSorting="grvRecord_Sorting" OnRowCommand="grvAgenda_RowCommand">
                        <Columns>
                            <asp:TemplateField HeaderText="S.No.">
                                <ItemTemplate>
                                    <%# Container.DataItemIndex+1 + "."%>
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="MeetingNo">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk3" runat="server" Text="MeetingNo" CommandName="Sort" Style="color: White"
                                        CommandArgument="StatusId"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblMeetingNo" runat="server" SkinID="lblskingen" Text='<%#Eval("MeetingNo") %>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="AgendaNo">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnkAgendaNo" runat="server" Text="Agenda No" CommandName="Sort"
                                        Style="color: White" CommandArgument="AgendaNo"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblAgendaNo" SkinID="lblSkinGen" Text='<%#Eval("AgendaNo")%>' runat="server" />
                                    <asp:HiddenField ID="hdnAgendaId" runat="server" />
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="SubjectNo">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnkSubjectNo" runat="server" Text="Subject No" CommandName="Sort"
                                        Style="color: White" CommandArgument="SubjectNo"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblSubjectNo" SkinID="lblSkinGen" Text='<%#Eval("SubjectNo")%>' runat="server" />
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="DepartmentName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnkDepartmentName" runat="server" Text="Department Name" CommandName="Sort"
                                        Style="color: White" CommandArgument="DepartmentName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblDepartmentName" runat="server" SkinID="lblskingen" Text='<%#Eval("DepartmentName")%>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="SubjectTypeName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk4" runat="server" Text="Subject Type Name" CommandName="Sort"
                                        Style="color: White" CommandArgument="SubjectTypeName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblSubjectTypeName" runat="server" SkinID="lblskingen" Text='<%#Eval("SubjectTypeName") %>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <%-- Step C2: who entered the item, every role, the same position; EnteredByName of the list
                                 procedures (step 33), empty when they do not return it --%>
                            <asp:TemplateField SortExpression="EnteredByName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnkEnteredBy" runat="server" Text="Entered by" CommandName="Sort"
                                        Style="color: White" CommandArgument="EnteredByName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblEnteredBy" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(EnteredBy(Container.DataItem)) %>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="bmms-col-person" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="ShortText">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk5" runat="server" Text="Short Text" CommandName="Sort" Style="color: White"
                                        CommandArgument="ShortText"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblShortText" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("ShortText")) %>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="AgendaStatusName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk6" runat="server" Text="Agenda Status" CommandName="Sort"
                                        Style="color: White" CommandArgument="AgendaStatusName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblAgendaStatusName" runat="server" SkinID="lblskingen" Text='<%#Eval("AgendaStatusName") %>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnEdit" CssClass="buttonEdit bmms-icon-btn" ToolTip="Edit" aria-label="Edit"
                                        CommandArgument='<%#Eval("AgendaId")%>' runat="server" CommandName="EditRec" />
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <%if (Session["RoleCode"].ToString() == "controller")
                                  { %>
                                    <asp:Button ID="btnDelete" CssClass="buttonDelete bmms-icon-btn" ToolTip="Delete" aria-label="Delete"
                                        CommandArgument='<%#Eval("AgendaId")%>' runat="server" CommandName="DeleteRec"
                                        OnClientClick="return confirm('Are you sure you want to delete this Record?');" />
                                    <%
                                        } %>
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
        </asp:Panel>

        <%-- Form screen: a new item (Add) or an item opened with Edit --%>
        <asp:Panel ID="pnlEditAgenda" runat="server">
            <div class="bmms-strip bmms-strip-5">
                <div class="bmms-strip-item">
                    <label for="ctl00_ContentPlaceHolder1_txtCommittee">
                        Committee Name</label>
                    <asp:TextBox ID="txtCommittee" runat="server" ReadOnly="true"></asp:TextBox>
                    <asp:HiddenField ID="hdnCommitteeId" runat="server" />
                </div>
                <div class="bmms-strip-item">
                    <label for="ctl00_ContentPlaceHolder1_txtMeetingNo">
                        Meeting No</label>
                    <asp:TextBox ID="txtMeetingNo" runat="server" ReadOnly="true"></asp:TextBox>
                    <asp:HiddenField ID="hdnMeetingId" runat="server" />
                </div>
                <div class="bmms-strip-item">
                    <label for="ctl00_ContentPlaceHolder1_txtDateOfMeeting">
                        Meeting Date</label>
                    <asp:TextBox ID="txtDateOfMeeting" runat="server" ReadOnly="true"></asp:TextBox>
                </div>
                <%-- A new item shows "Assigned on Save"; the box keeps the value the code puts in it (the mail and
                     the attachment names read it) and is not shown (display: none, so it is no Tab stop) --%>
                <div class="bmms-strip-item<%= btnSave.Text == "Save" ? " bmms-new-item" : "" %>">
                    <label for="ctl00_ContentPlaceHolder1_txtAgendaNo">
                        Agenda No</label>
                    <span class="bmms-strip-value">Assigned on Save</span>
                    <asp:TextBox ID="txtAgendaNo" runat="server" ReadOnly="true" CssClass="bmms-agendano-box"></asp:TextBox>
                    <asp:HiddenField ID="hdnAgendaId" runat="server" />
                </div>
                <div class="bmms-strip-item">
                    <label for="ctl00_ContentPlaceHolder1_txtSubjectNo">
                        Subject No</label>
                    <asp:TextBox ID="txtSubjectNo" runat="server"></asp:TextBox>
                </div>
            </div>

            <div class="wb-card">
                <h2 class="wb-card-header">
                    Item details</h2>
                <div class="wb-card-body">
                    <div class="bmms-grid-2">
                        <div class="bmms-field">
                            <label id="bmmsLblDepartment" for="ctl00_ContentPlaceHolder1_ddlDepartment">
                                Department <span class="wb-req">*</span></label>
                            <asp:Panel ID="pnlDepartment" runat="server">
                                <asp:DropDownList ID="ddlDepartment" runat="server">
                                </asp:DropDownList>
                            </asp:Panel>
                            <asp:TextBox ID="txtDepartment" runat="server" ReadOnly="true" aria-labelledby="bmmsLblDepartment"></asp:TextBox>
                            <asp:HiddenField ID="hdnDepartmentId" runat="server" />
                        </div>
                        <div class="bmms-field">
                            <label for="ctl00_ContentPlaceHolder1_ddlSubjectType">
                                Subject Type <span class="wb-req">*</span></label>
                            <asp:DropDownList ID="ddlSubjectType" runat="server">
                            </asp:DropDownList>
                        </div>
                    </div>
                    <div class="bmms-field">
                        <label for="ctl00_ContentPlaceHolder1_txtShortText">
                            Short Text <span class="wb-req">*</span></label>
                        <asp:TextBox ID="txtShortText" runat="server" ReadOnly="false" TextMode="MultiLine"
                            aria-describedby="bmmsShortTextHint"></asp:TextBox>
                        <p class="bmms-hint" id="bmmsShortTextHint">
                            Shown in the agenda list and on the Dashboard. Plain text only.</p>
                    </div>
                </div>
            </div>

            <div class="wb-card">
                <h2 class="wb-card-header">
                    Agenda content</h2>
                <div class="wb-card-body">
                    <fieldset class="bmms-fieldset">
                        <legend>Agenda Type</legend>
                        <asp:RadioButtonList ID="rdoAgendaType" runat="server" AutoPostBack="True" OnSelectedIndexChanged="rdoAgendaType_SelectedIndexChanged"
                            RepeatDirection="Horizontal" CssClass="wb-radio-list bmms-radios">
                            <asp:ListItem Text="Entry" Value="Entry" Selected="True"></asp:ListItem>
                            <asp:ListItem Text="Upload" Value="Upload"></asp:ListItem>
                        </asp:RadioButtonList>
                    </fieldset>
                    <asp:Panel ID="pnlUploadAgendaText" runat="server" Visible="false" CssClass="bmms-field">
                        <label for="ctl00_ContentPlaceHolder1_FileUploadAgendaText">
                            Agenda text file</label>
                        <asp:FileUpload ID="FileUploadAgendaText" runat="server" />
                        <span class="bmms-text-error">Note : Attach pdf files only.</span>
                    </asp:Panel>
                    <div class="bmms-field">
                        <span class="bmms-caption">Agenda Text</span>
                        <a id="aAgendaText" runat="server" target="_blank">View</a>
                        <bmms:RichTextEditor ID="ftxtAgendaText" runat="server" Height="100px" Label="Agenda Text" />
                        <div class="bmms-helpers">
                            <asp:Button ID="btnAddAgentaText" runat="server" Text="AddFile" OnClick="btnAddAgentaText_Click"
                                Style="visibility: hidden" />
                            <asp:TextBox ID="txtAgendaTextPath" runat="server" Width="150px" Style="visibility: hidden"></asp:TextBox>
                        </div>
                    </div>
                    <div class="bmms-field">
                        <span class="bmms-caption">Proposed Resolution</span>
                        <bmms:RichTextEditor ID="ftxtProposedResolution" runat="server" Height="100px" Label="Proposed Resolution" />
                    </div>
                </div>
            </div>

            <div class="wb-card">
                <h2 class="wb-card-header">
                    Files to be attached</h2>
                <div class="wb-card-body">
                    <asp:GridView ID="grvAttachedFiles" runat="server" AutoGenerateColumns="False" ShowHeader="False"
                        CssClass="bmms-files" GridLines="None">
                        <Columns>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:CheckBox ID="cbAttach" runat="server" Checked="true" CssClass="bmms-keep"
                                        Text='<%# "Keep " + HttpUtility.HtmlEncode(Eval("DisplayName")) %>' />
                                    <asp:HiddenField ID="hdnFilePath" runat="server" Value='<%#Eval("FilePathOrg") %>' />
                                </ItemTemplate>
                                <ItemStyle CssClass="bmms-files-keep" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="FilePath">
                                <ItemTemplate>
                                    <a href='<%# HttpUtility.HtmlEncode(Eval("FilePath")) %>' target="_blank">
                                        <%# HttpUtility.HtmlEncode(Eval("DisplayName")) %>
                                    </a>
                                </ItemTemplate>
                            </asp:TemplateField>
                        </Columns>
                        <SelectedRowStyle CssClass="bmms-row-selected" Font-Bold="True" />
                    </asp:GridView>
                    <div class="bmms-field">
                        <label for="ctl00_ContentPlaceHolder1_fuAttachment">
                            Choose a PDF to attach</label>
                        <asp:FileUpload runat="server" ID="fuAttachment" aria-describedby="bmmsAttachHint"></asp:FileUpload>
                        <span class="bmms-text-error">Note : Attach pdf files only.</span>
                        <p class="bmms-hint" id="bmmsAttachHint">
                            Large text: attach the document as a file instead of pasting it. Limit 4 MB per upload, the text of this form included.</p>
                    </div>
                    <div class="bmms-helpers">
                        <asp:Button ID="btnAddFile" runat="server" Text="AddFile" OnClick="btnAddFile_Click"
                            Style="visibility: hidden" />
                    </div>
                </div>
            </div>

            <%-- Hidden by CSS when neither comment panel is shown (the User; a new item shows at most one) --%>
            <div class="wb-card bmms-comments">
                <h2 class="wb-card-header">
                    Comments</h2>
                <div class="wb-card-body bmms-grid-2">
                    <%-- Step UN4: who wrote the comment and when, after the caption on one line (set and encoded in the code) --%>
                    <asp:Panel ID="pnlManagerComments" runat="server" CssClass="bmms-field">
                        <span class="bmms-caption">Manager's comment<asp:Label ID="lblManagerCommentBy" runat="server" CssClass="bmms-comment-by" /></span>
                        <bmms:RichTextEditor ID="ftxtManagerComments" runat="server" Height="100px" Label="Manager's comment" />
                    </asp:Panel>
                    <asp:Panel ID="pnlControllerComments" runat="server" CssClass="bmms-field">
                        <span class="bmms-caption">Controller's comment<asp:Label ID="lblControllerCommentBy" runat="server" CssClass="bmms-comment-by" /></span>
                        <bmms:RichTextEditor ID="ftxtControllerComments" runat="server" Height="100px" Label="Controller's comment" />
                    </asp:Panel>
                </div>
            </div>

            <div class="wb-actions bmms-actionbar">
                <asp:Button ID="btnSave" runat="server" CssClass="wb-btn" Text="Save" OnClick="btnSave_Click" />
                <asp:Button ID="btnCancel" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Cancel" OnClick="btnCancel_Click" />
            </div>
        </asp:Panel>
    </div>
</asp:Content>
