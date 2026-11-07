<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="Committee.aspx.cs" Inherits="BMMS.Master.Committee" Title="Untitled Page" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <link rel="stylesheet" href="../JScript/ColorPicker/js_color_picker_v2.css" media="screen">

    <script src="../JScript/ColorPicker/color_functions.js"></script>

    <script type="text/javascript" src="../JScript/ColorPicker/js_color_picker_v2.js"></script>

    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <div class="wb-page">
                <asp:UpdateProgress ID="UpdateProgress1" runat="server">
                    <ProgressTemplate>
                        <div class="divProgress">
                            <div class="divProgressBackground">
                            </div>
                            <div class="divProgressImg">
                                Loading ...</div>
                        </div>
                    </ProgressTemplate>
                </asp:UpdateProgress>
                <div class="wb-breadcrumb">
                    Master<span class="wb-breadcrumb-sep">/</span>Committee Master</div>
                <h1 class="wb-h1">
                    Committee Master</h1>
                <div aria-live="polite">
                    <div id="divErrLogin" runat="server" class="divErrorHide">
                        <span id="spanErrLogin" runat="server" class="lblError"></span>
                    </div>
                </div>
                <asp:Panel ID="pnlViewCommittee" runat="server">
                    <div class="wb-card">
                        <div class="wb-card-header">
                            Committees</div>
                        <div class="wb-toolbar">
                            <asp:Button ID="btnAdd" runat="server" CssClass="wb-btn" Text="Add" OnClick="btnAdd_Click" />
                        </div>
                        <div class="wb-table-scroll">
                            <asp:GridView ID="grvCommittee" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                                CssClass="wb-table" AllowSorting="true" DataKeyNames="CommitteeId" GridLines="None"
                                OnRowDataBound="grvCommittee_RowDataBound" OnSorting="grvRecord_Sorting" OnRowCommand="grvCommittee_RowCommand">
                                <Columns>
                                    <asp:TemplateField HeaderText="S.No.">
                                        <ItemTemplate>
                                            <%# Container.DataItemIndex+1 + "."%>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="wb-col-action" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="CommitteeCode">
                                        <HeaderTemplate>
                                            <asp:LinkButton ID="lnk1" runat="server" Text="Committee Code" CommandName="Sort"
                                                CommandArgument="CommitteeCode"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblCommitteeCode" SkinID="lblSkinGen" Text='<%# HttpUtility.HtmlEncode(Eval("CommitteeCode")) %>'
                                                runat="server" />
                                            <asp:HiddenField ID="hdnCommitteeCode" runat="server" />
                                        </ItemTemplate>
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="CommitteeName">
                                        <HeaderTemplate>
                                            <asp:LinkButton ID="lnk2" runat="server" Text="Committee Name" CommandName="Sort"
                                                CommandArgument="CommitteeName"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblEmployeName" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("CommitteeName")) %>'></asp:Label>
                                        </ItemTemplate>
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="IncorporationDate">
                                        <HeaderTemplate>
                                            <asp:LinkButton ID="lnk3" runat="server" Text="Incorporation Date" CommandName="Sort"
                                                CommandArgument="IncorporationDate"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblIncorporationDate" runat="server" SkinID="lblskingen" Text='<%#Eval("IncorporationDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="wb-col-action" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="CessationDate">
                                        <HeaderTemplate>
                                            <asp:LinkButton ID="lnk4" runat="server" Text="Cessation Date" CommandName="Sort"
                                                CommandArgument="CessationDate"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblCessationDate" runat="server" SkinID="lblskingen" Text='<%#Eval("CessationDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="wb-col-action" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="StatusName">
                                        <HeaderTemplate>
                                            <asp:LinkButton ID="lnk5" runat="server" Text="Status" CommandName="Sort" CommandArgument="StatusName"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblStatusName" runat="server" SkinID="lblskingen" Text='<%# HttpUtility.HtmlEncode(Eval("StatusName")) %>'></asp:Label>
                                        </ItemTemplate>
                                    </asp:TemplateField>
                                    <asp:TemplateField>
                                        <ItemTemplate>
                                            <asp:Button ID="btnEdit" CssClass="wb-link-btn wb-link-edit" Text="Edit" ToolTip="Edit"
                                                CommandArgument='<%#Eval("CommitteeId")%>' runat="server" CommandName="EditRec" />
                                        </ItemTemplate>
                                        <ItemStyle CssClass="wb-col-action" />
                                    </asp:TemplateField>
                                    <asp:TemplateField>
                                        <ItemTemplate>
                                            <asp:Button ID="btnDelete" CssClass="wb-link-btn wb-link-delete" Text="Delete" ToolTip="Delete"
                                                CommandArgument='<%#Eval("CommitteeId")%>' runat="server" CommandName="DeleteRec"
                                                OnClientClick="return confirm('Are you sure you want to delete this Record?');" />
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
                        <p class="wb-help">
                            Click a column heading to sort. Delete asks for confirmation; a committee that is
                            in use cannot be deleted.</p>
                    </div>
                </asp:Panel>
                <asp:Panel ID="pnlEditCommittee" runat="server">
                    <div class="wb-card">
                        <div class="wb-card-header">
                            Committee details</div>
                        <div class="wb-card-body">
                            <div class="wb-row">
                                <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtCommitteeCode">
                                    Committee Code</label>
                                <div class="wb-field">
                                    <asp:TextBox ID="txtCommitteeCode" runat="server" MaxLength="6" ReadOnly="true"></asp:TextBox>
                                    <asp:HiddenField ID="hdnCommitteeId" runat="server" />
                                </div>
                            </div>
                            <div class="wb-row">
                                <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtCommitteeName">
                                    Committee Name <span class="wb-req">*</span></label>
                                <div class="wb-field">
                                    <asp:TextBox ID="txtCommitteeName" runat="server"></asp:TextBox>
                                </div>
                            </div>
                            <div class="wb-row">
                                <label class="wb-label" for="ctl00_ContentPlaceHolder1_chkBoard">
                                    Is Board <span class="wb-req">*</span></label>
                                <div class="wb-field">
                                    <asp:CheckBox ID="chkBoard" runat="server" Checked="false" />
                                </div>
                            </div>
                            <div class="wb-row">
                                <div class="wb-label">
                                    Incorporation Date <span class="wb-req">*</span></div>
                                <div class="wb-field">
                                    <asp:TextBox ID="txtIncorporationDate" runat="server" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                                    <asp:ImageButton runat="Server" ID="imgIncorporationDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                    <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender2" runat="server"
                                        TargetControlID="txtIncorporationDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                        PopupButtonID="imgIncorporationDate">
                                    </cc1:CalendarExtender>
                                </div>
                            </div>
                            <div class="wb-row">
                                <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtMeetingStartNo">
                                    Meeting Start No <span class="wb-req">*</span></label>
                                <div class="wb-field wb-field-short">
                                    <asp:TextBox ID="txtMeetingStartNo" runat="server" MaxLength="5"></asp:TextBox>
                                    <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender1" runat="server" TargetControlID="txtMeetingStartNo"
                                        ValidChars="0123456789" FilterMode="ValidChars" FilterType="Custom">
                                    </cc1:FilteredTextBoxExtender>
                                </div>
                            </div>
                            <div class="wb-row">
                                <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtColor">
                                    Committee Color Code</label>
                                <div class="wb-field">
                                    <input id="txtColor" name="txtColor" runat="server" value="#FFFFFF" style="width: 80px;">
                                    <input type="button" value="..." onclick="showColorPicker(this,ctl00_ContentPlaceHolder1_txtColor);	document.getElementById('ctl00_ContentPlaceHolder1_txtColor').style.backgroundColor = document.getElementById('ctl00_ContentPlaceHolder1_txtColor').value;">
                                </div>
                            </div>
                            <div class="wb-row">
                                <div class="wb-label">
                                    Cessation Date</div>
                                <div class="wb-field">
                                    <asp:TextBox ID="txtCessationDate" runat="server" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                                    <asp:ImageButton runat="Server" ID="imgCessationDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                    <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender1" runat="server"
                                        TargetControlID="txtCessationDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                        PopupButtonID="imgCessationDate">
                                    </cc1:CalendarExtender>
                                </div>
                            </div>
                            <div class="wb-row">
                                <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlStatus">
                                    Status <span class="wb-req">*</span></label>
                                <div class="wb-field">
                                    <asp:DropDownList ID="ddlStatus" runat="server">
                                    </asp:DropDownList>
                                </div>
                            </div>
                            <div class="wb-actions">
                                <asp:Button ID="btnSave" runat="server" CssClass="wb-btn" Text="Save" OnClick="btnSave_Click" />
                                <asp:Button ID="btnCancel" runat="server" CssClass="wb-btn wb-btn-secondary" Text="Cancel"
                                    OnClick="btnCancel_Click" />
                            </div>
                        </div>
                    </div>
                </asp:Panel>
            </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
