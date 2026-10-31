<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="Member.aspx.cs" Inherits="BMMS.Master.Member" Title="Untitled Page" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="wb-page">
        <div class="wb-breadcrumb">
            Master<span class="wb-breadcrumb-sep">/</span>Member Master</div>
        <h1 class="wb-h1">
            Member Master</h1>
        <div aria-live="polite">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
        </div>
        <asp:Panel ID="pnlViewMember" runat="server">
            <div class="wb-card">
                <div class="wb-card-header">
                    Members</div>
                <div class="wb-toolbar">
                    <asp:Button ID="btnAdd" runat="server" CssClass="wb-btn" Text="Add" OnClick="btnAdd_Click" />
                </div>
                <div class="wb-table-scroll">
                    <asp:GridView ID="grvMember" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                        CssClass="wb-table wb-table-wide" AllowSorting="true" DataKeyNames="MemberId" GridLines="None"
                        OnRowDataBound="grvMember_RowDataBound" OnSorting="grvRecord_Sorting" OnRowCommand="grvMember_RowCommand">
                        <Columns>
                            <asp:TemplateField HeaderText="S.No.">
                                <ItemTemplate>
                                    <%# Container.DataItemIndex+1 + "."%>
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="MemberCode">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk1" runat="server" Text="Member Code" CommandName="Sort" CommandArgument="MemberCode"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblMemberCode" SkinID="lblSkinGen" Text='<%#Eval("MemberCode")%>'
                                        runat="server" />
                                    <asp:HiddenField ID="hdnMemberCode" runat="server" />
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="MemberName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk2" runat="server" Text="Member Name" CommandName="Sort" CommandArgument="MemberName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblEmployeName" runat="server" SkinID="lblskingen" Text='<%#Eval("MemberName")%>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="DesignationName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk3" runat="server" Text="Designation" CommandName="Sort" CommandArgument="DesignationName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblDepartmentName" runat="server" SkinID="lblskingen" Text='<%#Eval("DesignationName")%>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="EmailId">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk4" runat="server" Text="Email Id" CommandName="Sort" CommandArgument="EmailId"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblEmailId" runat="server" SkinID="lblskingen" Text='<%#Eval("EmailId")%>'></asp:Label>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="DOJ">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk6" runat="server" Text="Date of Join" CommandName="Sort" CommandArgument="DOJ"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblDOJ" runat="server" SkinID="lblskingen" Text='<%#Eval("DOJ")%>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <%--<asp:TemplateField SortExpression="PhotoPath">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk5" runat="server" Text="Photo" CommandName="Sort" Style="color: White"
                                        CommandArgument="PhotoPath"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <img id="imgNoPhoto" alt="" width="50px" src="../Files/MemberPhoto/MalePhoto.png" />
                                    <img id="imgPhoto" alt="-" width="50px" src='<%#Eval("PhotoPath").ToString().Replace("~/","../")%>' />
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                            </asp:TemplateField>--%>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnEdit" CssClass="wb-link-btn wb-link-edit" Text="Edit" ToolTip="Edit"
                                        CommandArgument='<%#Eval("MemberId")%>' runat="server" CommandName="EditRec" />
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnDelete" CssClass="wb-link-btn wb-link-delete" Text="Delete" ToolTip="Delete"
                                        CommandArgument='<%#Eval("MemberId")%>' runat="server" CommandName="DeleteRec"
                                        OnClientClick="return confirm('Are you sure you want to delete this Record?');" />
                                </ItemTemplate>
                                <ItemStyle CssClass="wb-col-action" />
                            </asp:TemplateField>
                        </Columns>
                        <EmptyDataTemplate>
                            <div class="divNoRecord">
                                No Members Found</div>
                        </EmptyDataTemplate>
                    </asp:GridView>
                </div>
                <p class="wb-help">
                    Click a column heading to sort. Delete asks for confirmation; a member that is in
                    use cannot be deleted.</p>
            </div>
        </asp:Panel>
        <asp:Panel ID="pnlEditMember" runat="server">
            <div class="wb-card">
                <div class="wb-card-header">
                    Member details</div>
                <div class="wb-card-body">
                    <div class="wb-section-title">
                        Personal</div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtMemberCode">
                            Member Code</label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtMemberCode" runat="server" MaxLength="6" ReadOnly="true"></asp:TextBox>
                            <asp:HiddenField ID="hdnMemberId" runat="server" />
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtMemberName">
                            Member Name <span class="wb-req">*</span></label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtMemberName" runat="server"></asp:TextBox>
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlSex">
                            Sex <span class="wb-req">*</span></label>
                        <div class="wb-field">
                            <asp:DropDownList ID="ddlSex" runat="server">
                            </asp:DropDownList>
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlDesignation">
                            Designation <span class="wb-req">*</span></label>
                        <div class="wb-field">
                            <asp:DropDownList ID="ddlDesignation" runat="server">
                            </asp:DropDownList>
                        </div>
                    </div>
                    <div class="wb-row">
                        <div class="wb-label">
                            Date of Birth <span class="wb-req">*</span></div>
                        <div class="wb-field wb-field-short">
                            <asp:TextBox ID="txtDOB" runat="server" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                            <asp:ImageButton runat="Server" ID="imgDOB" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                            <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender2" runat="server"
                                TargetControlID="txtDOB" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                PopupButtonID="imgDOB">
                            </cc1:CalendarExtender>
                        </div>
                    </div>
                    <div class="wb-row">
                        <div class="wb-label">
                            Date of Join <span class="wb-req">*</span></div>
                        <div class="wb-field wb-field-short">
                            <asp:TextBox ID="txtDOJ" runat="server" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                            <asp:ImageButton runat="Server" ID="imgDOJ" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                            <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender1" runat="server"
                                TargetControlID="txtDOJ" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                PopupButtonID="imgDOJ">
                            </cc1:CalendarExtender>
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtEmailId">
                            Email Id <span class="wb-req">*</span></label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtEmailId" runat="server"></asp:TextBox>
                        </div>
                    </div>
                    <div class="wb-section-title">
                        Address</div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtAddress1">
                            Address1</label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtAddress1" runat="server"></asp:TextBox>
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtAddress2">
                            Address2</label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtAddress2" runat="server"></asp:TextBox>
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtAddress3">
                            Address3</label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtAddress3" runat="server"></asp:TextBox>
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtCityName">
                            City</label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtCityName" runat="server"></asp:TextBox>
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_ddlState">
                            State</label>
                        <div class="wb-field">
                            <asp:DropDownList ID="ddlState" runat="server">
                            </asp:DropDownList>
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtPinCode">
                            Pin Code</label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtPinCode" runat="server"></asp:TextBox>
                        </div>
                    </div>
                    <div class="wb-section-title">
                        Documents</div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_fileUploadPhotoPath">
                            Photo Path</label>
                        <div class="wb-field">
                            <asp:FileUpload ID="fileUploadPhotoPath" runat="server" />
                        </div>
                    </div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_fileUploadReasumePath">
                            Resume Path</label>
                        <div class="wb-field">
                            <asp:FileUpload ID="fileUploadReasumePath" runat="server" />
                        </div>
                    </div>
                    <div class="wb-section-title">
                        Directorship and status</div>
                    <div class="wb-row">
                        <label class="wb-label" for="ctl00_ContentPlaceHolder1_txtDinNo">
                            DIN No</label>
                        <div class="wb-field">
                            <asp:TextBox ID="txtDinNo" runat="server"></asp:TextBox>
                        </div>
                    </div>
                    <div class="wb-row">
                        <div class="wb-label">
                            Date of Relieving</div>
                        <div class="wb-field">
                            <asp:TextBox ID="txtRelievingDate" runat="server" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                            <asp:ImageButton runat="Server" ID="imgRelievingDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                            <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender3" runat="server"
                                TargetControlID="txtRelievingDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                PopupButtonID="imgRelievingDate">
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
                    <%-- saved file paths: must stay rendered and posted back; hidden by the wrapper only --%>
                    <div class="wb-hidden">
                        <asp:TextBox ID="txtPhotoPath" runat="server" Style="visibility: hidden"></asp:TextBox>
                        <asp:TextBox ID="txtResumePath" runat="server" Style="visibility: hidden"></asp:TextBox>
                    </div>
                </div>
            </div>
        </asp:Panel>
    </div>
</asp:Content>
