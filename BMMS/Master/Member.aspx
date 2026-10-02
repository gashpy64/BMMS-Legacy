<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="Member.aspx.cs" Inherits="BMMS.Master.Member" Title="Untitled Page" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="formContent">
        <div class="formPanel">
            <div class="divHeader">
                :: Member Master</div>
            <div class="divRowFixed">
            </div>
            <div class="divRow" style="height: 25px">
                <div id="divErrLogin" runat="server" class="divErrorHide">
                    <span id="spanErrLogin" runat="server" class="lblError"></span>
                </div>
            </div>
            <asp:Panel ID="pnlViewMember" runat="server">
                <div class="divRow" style="margin: auto; float: none; width: 850px;">
                    <div class="divRow">
                        <asp:Button ID="btnAdd" runat="server" CssClass="button" Text="Add" OnClick="btnAdd_Click" />
                    </div>
                    <div class="divRow">
                        <asp:GridView ID="grvMember" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                            CssClass="contentTable1" AllowSorting="true" CellPadding="4" DataKeyNames="MemberId"
                            Font-Names="Verdana, Arial, Helvetica, sans-serif" Font-Size="X-Small" ForeColor="#333333"
                            GridLines="Horizontal" Height="32px" Width="100%" OnRowDataBound="grvMember_RowDataBound"
                            OnSorting="grvRecord_Sorting" OnRowCommand="grvMember_RowCommand">
                            <HeaderStyle CssClass="contentTableHeader" HorizontalAlign="Center" Font-Bold="true" />
                            <Columns>
                                <asp:TemplateField HeaderText="S.No.">
                                    <ItemTemplate>
                                        <%# Container.DataItemIndex+1 + "."%>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                        Width="10px" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="MemberCode">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="lnk1" runat="server" Text="Member Code" CommandName="Sort" Style="color: White"
                                            CommandArgument="MemberCode"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblMemberCode" SkinID="lblSkinGen" Text='<%#Eval("MemberCode")%>'
                                            runat="server" />
                                        <asp:HiddenField ID="hdnMemberCode" runat="server" />
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="MemberName">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="lnk2" runat="server" Text="Member Name" CommandName="Sort" Style="color: White"
                                            CommandArgument="MemberName"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblEmployeName" runat="server" SkinID="lblskingen" Text='<%#Eval("MemberName")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="DesignationName">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="lnk3" runat="server" Text="Designation" CommandName="Sort" Style="color: White"
                                            CommandArgument="DesignationName"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblDepartmentName" runat="server" SkinID="lblskingen" Text='<%#Eval("DesignationName")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="EmailId">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="lnk3" runat="server" Text="Email Id" CommandName="Sort" Style="color: White"
                                            CommandArgument="EmailId"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblEmailId" runat="server" SkinID="lblskingen" Text='<%#Eval("EmailId")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="DOJ">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="lnk3" runat="server" Text="Date of Join" CommandName="Sort" Style="color: White"
                                            CommandArgument="DOJ"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblDOJ" runat="server" SkinID="lblskingen" Text='<%#Eval("DOJ")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
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
                                        <asp:Button ID="btnEdit" Width="18px" Height="18px" CssClass="buttonEdit" ToolTip="Edit"
                                            CommandArgument='<%#Eval("MemberId")%>' runat="server" CommandName="EditRec" />
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                        Width="30px" />
                                </asp:TemplateField>
                                <asp:TemplateField>
                                    <ItemTemplate>
                                        <asp:Button ID="btnDelete" Width="18px" Height="18px" CssClass="buttonDelete" ToolTip="Delete"
                                            CommandArgument='<%#Eval("MemberId")%>' runat="server" CommandName="DeleteRec"
                                            OnClientClick="return confirm('Are you sure you want to delete this Record?');" />
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                        Width="30px" />
                                </asp:TemplateField>
                            </Columns>
                            <EmptyDataTemplate>
                                <div class="divNoRecord">
                                    No Members Found</div>
                            </EmptyDataTemplate>
                        </asp:GridView>
                    </div>
                </div>
            </asp:Panel>
            <asp:Panel ID="pnlEditMember" runat="server">
                <div class="divRow">
                    <div class="divRow">
                        <div class="divRowLeft" style="width: 50%;">
                            <div class="divRowLeft">
                                Member Code :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtMemberCode" runat="server" MaxLength="6" ReadOnly="true" Width="200px"></asp:TextBox>
                                <asp:HiddenField ID="hdnMemberId" runat="server" />
                            </div>
                        </div>
                        <div class="divRowLeft">
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRowLeft" style="width: 50%;">
                            <div class="divRowLeft">
                                Member Name :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtMemberName" runat="server" Width="200px"></asp:TextBox>
                                <span class="spanMandatory">*</span>
                            </div>
                        </div>
                        <div class="divRowLeft">
                            <div class="divRowLeft">
                                Sex :
                            </div>
                            <div class="divRowRight">
                                <asp:DropDownList ID="ddlSex" runat="server" Width="100px">
                                </asp:DropDownList>
                                <span class="spanMandatory">*</span>
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRowLeft" style="width: 50%;">
                            <div class="divRowLeft">
                                Designation :
                            </div>
                            <div class="divRowRight">
                                <asp:DropDownList ID="ddlDesignation" runat="server" Width="220px">
                                </asp:DropDownList>
                                <span class="spanMandatory">*</span>
                            </div>
                        </div>
                        <div class="divRowLeft">
                            <div class="divRowLeft">
                                Date of Birth :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtDOB" runat="server" Width="100px" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                                <span class="spanMandatory">*</span>
                                <asp:ImageButton runat="Server" ID="imgDOB" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender2" runat="server"
                                    TargetControlID="txtDOB" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                    PopupButtonID="imgDOB">
                                </cc1:CalendarExtender>
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRowLeft" style="width: 50%;">
                            <div class="divRowLeft">
                                Date of Join :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtDOJ" runat="server" Width="100px" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                                <span class="spanMandatory">*</span>
                                <asp:ImageButton runat="Server" ID="imgDOJ" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender1" runat="server"
                                    TargetControlID="txtDOJ" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                    PopupButtonID="imgDOJ">
                                </cc1:CalendarExtender>
                            </div>
                        </div>
                        <div class="divRowLeft">
                            <div class="divRowLeft">
                                EmailId :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtEmailId" runat="server" Width="180px"></asp:TextBox>
                                <span class="spanMandatory">*</span>
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRowLeft" style="width: 50%;">
                            <div class="divRowLeft">
                                Address1 :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtAddress1" runat="server" Width="200px"></asp:TextBox>
                            </div>
                        </div>
                        <div class="divRowLeft">
                            <div class="divRowLeft">
                                Address2 :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtAddress2" runat="server" Width="200px"></asp:TextBox>
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRowLeft" style="width: 50%;">
                            <div class="divRowLeft">
                                Address3 :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtAddress3" runat="server" Width="200px"></asp:TextBox>
                            </div>
                        </div>
                        <div class="divRowLeft">
                            <div class="divRowLeft">
                                City :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtCityName" runat="server" Width="200px"></asp:TextBox>
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRowLeft" style="width: 50%;">
                            <div class="divRowLeft">
                                State :
                            </div>
                            <div class="divRowRight">
                                <asp:DropDownList ID="ddlState" runat="server" Width="200px">
                                </asp:DropDownList>
                            </div>
                        </div>
                        <div class="divRowLeft">
                            <div class="divRowLeft">
                                Pin Code :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtPinCode" runat="server" Width="200px"></asp:TextBox>
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRowLeft" style="width: 50%;">
                            <div class="divRowLeft">
                                Photo Path :
                            </div>
                            <div class="divRowRight">
                                <asp:FileUpload ID="fileUploadPhotoPath" runat="server" />
                            </div>
                        </div>
                        <div class="divRowLeft">
                            <div class="divRowLeft">
                                Resume Path :
                            </div>
                            <div class="divRowRight">
                                <asp:FileUpload ID="fileUploadReasumePath" runat="server" />
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRowLeft" style="width: 50%;">
                            <div class="divRowLeft">
                                DinNo :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtDinNo" runat="server" Width="200px"></asp:TextBox>
                            </div>
                        </div>
                        <div class="divRowLeft">
                            <div class="divRowLeft">
                                Date of Relieving :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtRelievingDate" runat="server" Width="100px" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                                <asp:ImageButton runat="Server" ID="imgRelievingDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender3" runat="server"
                                    TargetControlID="txtRelievingDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                    PopupButtonID="imgRelievingDate">
                                </cc1:CalendarExtender>
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRowLeft" style="width: 50%;">
                            <div class="divRowLeft">
                                Status :
                            </div>
                            <div class="divRowRight">
                                <asp:DropDownList ID="ddlStatus" runat="server" Width="155px">
                                </asp:DropDownList>
                                <span class="spanMandatory">*</span>
                            </div>
                        </div>
                        <div class="divRowLeft">
                            <div class="divRowLeft">
                                &nbsp;
                            </div>
                            <div class="divRowRight">
                                &nbsp;
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
                                <asp:TextBox ID="txtPhotoPath" runat="server" Width="100px" Style="visibility: hidden"></asp:TextBox>
                                <asp:TextBox ID="txtResumePath" runat="server" Width="100px" Style="visibility: hidden"></asp:TextBox>
                            </div>
                        </div>
                    </div>
                </div>
            </asp:Panel>
        </div>
    </div>
</asp:Content>
