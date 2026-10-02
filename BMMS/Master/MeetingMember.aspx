<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="MeetingMember.aspx.cs" Inherits="BMMS.Master.MeetingMember" 
    Title="Untitled Page" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="formContent">
    <div class="formPanel">
        <div class="divHeader">
        :: Meeting Member Tagging</div>
        <div class="divRowFixed"></div>
        <div class="divRow" style="height: 25px">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
        </div>
        <asp:Panel ID="pnlViewMeetingMember" runat="server">
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
                <div class="divRow">
                    <div class="divRowLeft">
                        Meeting No :
                    </div>
                    <div class="divRowRight">
                        <asp:DropDownList ID="ddlMeeting" runat="server" Width="150px" AutoPostBack="true"
                            OnSelectedIndexChanged="ddlMeeting_SelectedIndexChanged">
                        </asp:DropDownList>
                        <span class="spanMandatory">*</span>
                    </div>
                </div>
            </div>
            <div class="divRow" style="margin: auto; float: none; width: 700px;">
                <div class="divRow">
                    <asp:Button ID="btnAdd" runat="server" CssClass="button" Text="Add" OnClick="btnAdd_Click" />
                </div>
                <div class="divRow">
                    <asp:GridView ID="grvMeetingMember" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                        CssClass="contentTable1" AllowSorting="true" CellPadding="4" DataKeyNames="MeetingMemberId"
                        Font-Names="Verdana, Arial, Helvetica, sans-serif" Font-Size="X-Small" ForeColor="#333333"
                        GridLines="Horizontal" Height="32px" Width="100%" OnRowDataBound="grvMeetingMember_RowDataBound"
                        OnSorting="grvRecord_Sorting" OnRowCommand="grvMeetingMember_RowCommand">
                        <HeaderStyle CssClass="contentTableHeader" HorizontalAlign="Center" Font-Bold="true" />
                        <Columns>
                            <asp:TemplateField HeaderText="S.No.">
                                <ItemTemplate>
                                    <%# Container.DataItemIndex+1 + "."%>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                    Width="10px" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="MeetingNo">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk1" runat="server" Text="Meeting No" CommandName="Sort" Style="color: White"
                                        CommandArgument="MeetingNo"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblMeetingMemberCode" SkinID="lblSkinGen" Text='<%#Eval("MeetingNo")%>'
                                        runat="server" />
                                    <asp:HiddenField ID="hdnMeetingMemberCode" runat="server" />
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
                                    <asp:LinkButton ID="lnkDesignationName" runat="server" Text="Designation" CommandName="Sort"
                                        Style="color: White" CommandArgument="DesignationName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblDesignationName" runat="server" SkinID="lblskingen" Text='<%#Eval("DesignationName")%>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="MemberTypeName">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk3" runat="server" Text="Member Type" CommandName="Sort" Style="color: White"
                                        CommandArgument="MemberTypeName"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblMemberTypeName" runat="server" SkinID="lblskingen" Text='<%#Eval("MemberTypeName")%>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                            </asp:TemplateField>
                            <asp:TemplateField SortExpression="StatusId">
                                <HeaderTemplate>
                                    <asp:LinkButton ID="lnk4" runat="server" Text="Status" CommandName="Sort" Style="color: White"
                                        CommandArgument="StatusId"></asp:LinkButton>
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:Label ID="lblStatusId" runat="server" SkinID="lblskingen" Text='<%#Eval("StatusId").ToString() == "0" ? "InActive" : "Active" %>'></asp:Label>
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnEdit" Width="18px" Height="18px" CssClass="buttonEdit" ToolTip="Edit"
                                        CommandArgument='<%#Eval("MeetingMemberId")%>' runat="server" CommandName="EditRec" />
                                </ItemTemplate>
                                <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                    Width="30px" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:Button ID="btnDelete" Width="18px" Height="18px" CssClass="buttonDelete" ToolTip="Delete"
                                        CommandArgument='<%#Eval("MeetingMemberId")%>' runat="server" CommandName="DeleteRec"
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
        </asp:Panel>
        <asp:Panel ID="pnlEditMeetingMember" runat="server">
            <div class="divRow">
                <div class="divRow" style="width: 70%;">
                    <div class="divRow">
                        <div class="divRowLeft">
                            Committee Name :
                        </div>
                        <div class="divRowRight">
                            <asp:TextBox ID="txtCommitteeName" runat="server" ReadOnly="true"></asp:TextBox>
                            <asp:HiddenField ID="hdnCommitteeId" runat="server" />
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRow">
                            <div class="divRowLeft">
                                Meeting No :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtMeetingNo" runat="server" ReadOnly="true"></asp:TextBox>
                                <asp:HiddenField ID="hdnMeetingId" runat="server" />
                                <asp:HiddenField ID="hdnMeetingMemberId" runat="server" />
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
                                Status :
                            </div>
                            <div class="divRowRight">
                                <asp:DropDownList ID="ddlStatus" runat="server" Width="150px">
                                </asp:DropDownList>
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
