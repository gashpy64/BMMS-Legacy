<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="Committee.aspx.cs" Inherits="BMMS.Master.Committee" Title="Untitled Page" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <link rel="stylesheet" href="../JScript/ColorPicker/js_color_picker_v2.css" media="screen">

    <script src="../JScript/ColorPicker/color_functions.js"></script>

    <script type="text/javascript" src="../JScript/ColorPicker/js_color_picker_v2.js"></script>

    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
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
            <div class="formContent">
                <div class="formPanel">
                    <div class="divHeader">
                        :: Committee Master</div>
                    <div class="divRowFixed">
                    </div>
                    <div class="divRow" style="height: 25px">
                        <div id="divErrLogin" runat="server" class="divErrorHide">
                            <span id="spanErrLogin" runat="server" class="lblError"></span>
                        </div>
                    </div>
                    <asp:Panel ID="pnlViewCommittee" runat="server">
                        <div class="divRow" style="margin: auto; float: none; width: 700px;">
                            <div class="divRow">
                                <asp:Button ID="btnAdd" runat="server" CssClass="button" Text="Add" OnClick="btnAdd_Click" />
                            </div>
                            <div class="divRow">
                                <div class="divRowGridScroll">
                                    <asp:GridView ID="grvCommittee" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                                        CssClass="contentTable1" AllowSorting="true" CellPadding="4" DataKeyNames="CommitteeId"
                                        Font-Names="Verdana, Arial, Helvetica, sans-serif" Font-Size="X-Small" ForeColor="#333333"
                                        GridLines="Horizontal" Height="32px" Width="100%" OnRowDataBound="grvCommittee_RowDataBound"
                                        OnSorting="grvRecord_Sorting" OnRowCommand="grvCommittee_RowCommand">
                                        <HeaderStyle CssClass="contentTableHeader" HorizontalAlign="Center" Font-Bold="true" />
                                        <Columns>
                                            <asp:TemplateField HeaderText="S.No.">
                                                <ItemTemplate>
                                                    <%# Container.DataItemIndex+1 + "."%>
                                                </ItemTemplate>
                                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                                    Width="10px" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="CommitteeCode">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="lnk1" runat="server" Text="Committee Code" CommandName="Sort"
                                                        Style="color: White" CommandArgument="CommitteeCode"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblCommitteeCode" SkinID="lblSkinGen" Text='<%#Eval("CommitteeCode")%>'
                                                        runat="server" />
                                                    <asp:HiddenField ID="hdnCommitteeCode" runat="server" />
                                                </ItemTemplate>
                                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="CommitteeName">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="lnk2" runat="server" Text="Committee Name" CommandName="Sort"
                                                        Style="color: White" CommandArgument="CommitteeName"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblEmployeName" runat="server" SkinID="lblskingen" Text='<%#Eval("CommitteeName")%>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="IncorporationDate">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="lnk3" runat="server" Text="Incorporation Date" CommandName="Sort"
                                                        Style="color: White" CommandArgument="IncorporationDate"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblIncorporationDate" runat="server" SkinID="lblskingen" Text='<%#Eval("IncorporationDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="CessationDate">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="lnk4" runat="server" Text="Cessation Date" CommandName="Sort"
                                                        Style="color: White" CommandArgument="CessationDate"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblCessationDate" runat="server" SkinID="lblskingen" Text='<%#Eval("CessationDate", "{0:dd-MMM-yyyy}")%>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                            </asp:TemplateField>
                                            <asp:TemplateField SortExpression="StatusName">
                                                <HeaderTemplate>
                                                    <asp:LinkButton ID="lnk5" runat="server" Text="Status" CommandName="Sort" Style="color: White"
                                                        CommandArgument="StatusName"></asp:LinkButton>
                                                </HeaderTemplate>
                                                <ItemTemplate>
                                                    <asp:Label ID="lblStatusName" runat="server" SkinID="lblskingen" Text='<%#Eval("StatusName")%>'></asp:Label>
                                                </ItemTemplate>
                                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                            </asp:TemplateField>
                                            <asp:TemplateField>
                                                <ItemTemplate>
                                                    <asp:Button ID="btnEdit" Width="18px" Height="18px" CssClass="buttonEdit" ToolTip="Edit"
                                                        CommandArgument='<%#Eval("CommitteeId")%>' runat="server" CommandName="EditRec" />
                                                </ItemTemplate>
                                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                                    Width="30px" />
                                            </asp:TemplateField>
                                            <asp:TemplateField>
                                                <ItemTemplate>
                                                    <asp:Button ID="btnDelete" Width="18px" Height="18px" CssClass="buttonDelete" ToolTip="Delete"
                                                        CommandArgument='<%#Eval("CommitteeId")%>' runat="server" CommandName="DeleteRec"
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
                        </div>
                    </asp:Panel>
                    <asp:Panel ID="pnlEditCommittee" runat="server">
                        <div class="divRow">
                            <div class="divRow">
                                <div class="divRow">
                                    <div class="divRowLeft">
                                        Committee Code :
                                    </div>
                                    <div class="divRowRight">
                                        <asp:TextBox ID="txtCommitteeCode" runat="server" MaxLength="6" ReadOnly="true" Width="150px"></asp:TextBox>
                                        <asp:HiddenField ID="hdnCommitteeId" runat="server" />
                                    </div>
                                </div>
                            </div>
                            <div class="divRow">
                                <div class="divRow">
                                    <div class="divRowLeft">
                                        Committee Name :
                                    </div>
                                    <div class="divRowRight">
                                        <asp:TextBox ID="txtCommitteeName" runat="server" Width="150px"></asp:TextBox>
                                        <span class="spanMandatory">*</span>
                                    </div>
                                </div>
                            </div>
                            <div class="divRow">
                                <div class="divRow">
                                    <div class="divRowLeft">
                                        Is Board :
                                    </div>
                                    <div class="divRowRight">
                                        <asp:CheckBox ID="chkBoard" runat="server" Checked="false" />
                                        <span class="spanMandatory">*</span>
                                    </div>
                                </div>
                            </div>
                            <div class="divRow">
                                <div class="divRow">
                                    <div class="divRowLeft">
                                        Incorporation Date :
                                    </div>
                                    <div class="divRowRight">
                                        <asp:TextBox ID="txtIncorporationDate" runat="server" Width="100px" onfocus="this.blur();"
                                            TabIndex="-1"></asp:TextBox>
                                        <asp:ImageButton runat="Server" ID="imgIncorporationDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                        <span class="spanMandatory">*</span>
                                        <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender2" runat="server"
                                            TargetControlID="txtIncorporationDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                            PopupButtonID="imgIncorporationDate">
                                        </cc1:CalendarExtender>
                                    </div>
                                </div>
                            </div>
                            <div class="divRow">
                                <div class="divRow">
                                    <div class="divRowLeft">
                                        MeetingStartNo :
                                    </div>
                                    <div class="divRowRight">
                                        <asp:TextBox ID="txtMeetingStartNo" runat="server" Width="50px" MaxLength="5"
                                            style="text-align:right;"></asp:TextBox>
                                        <span class="spanMandatory">*</span>
                                        <cc1:FilteredTextBoxExtender ID="FilteredTextBoxExtender1" runat="server" 
                                            TargetControlID="txtMeetingStartNo"
                                            ValidChars="0123456789" FilterMode="ValidChars" FilterType="Custom">
                                        </cc1:FilteredTextBoxExtender>
                                    </div>
                                </div>
                            </div>
                            <div class="divRow">
                                <div class="divRow">
                                    <div class="divRowLeft">
                                        Committee Color Code :
                                    </div>
                                    <div class="divRowRight">
                                        <input id="txtColor" name="txtColor" runat="server" value="#FFFFFF" style="width: 80px;">
                                        <input type="button" value="..." onclick="showColorPicker(this,ctl00_ContentPlaceHolder1_txtColor);	document.getElementById('ctl00_ContentPlaceHolder1_txtColor').style.backgroundColor = document.getElementById('ctl00_ContentPlaceHolder1_txtColor').value;">
                                    </div>
                                </div>
                            </div>
                            <div class="divRow">
                                <div class="divRow">
                                    <div class="divRowLeft">
                                        Cessation Date :
                                    </div>
                                    <div class="divRowRight">
                                        <asp:TextBox ID="txtCessationDate" runat="server" Width="100px" onfocus="this.blur();"
                                            TabIndex="-1"></asp:TextBox>
                                        <asp:ImageButton runat="Server" ID="imgCessationDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                        <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender1" runat="server"
                                            TargetControlID="txtCessationDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                            PopupButtonID="imgCessationDate">
                                        </cc1:CalendarExtender>
                                    </div>
                                </div>
                            </div>
                            <div class="divRow">
                                <div class="divRow">
                                    <div class="divRowLeft">
                                        Status :
                                    </div>
                                    <div class="divRowRight">
                                        <asp:DropDownList ID="ddlStatus" runat="server" Width="155px">
                                        </asp:DropDownList>
                                        <span class="spanMandatory">*</span>
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
                    </asp:Panel>
                </div>
            </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
