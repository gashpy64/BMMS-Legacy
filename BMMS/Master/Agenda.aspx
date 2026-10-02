<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="Agenda.aspx.cs" Inherits="BMMS.Master.Agenda" Title="Untitled Page"
    ValidateRequest="false" MaintainScrollPositionOnPostback="true" %>

<%@ Register Assembly="FreeTextBox" Namespace="FreeTextBoxControls" TagPrefix="FTB" %>
<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">

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
    <div class="formContent">
        <div class="formPanel">
            <div class="divHeader">
                :: Agenda</div>
            <div class="divRowFixed">
            </div>
            <div class="divRow" style="height: 25px">
                <div id="divErrLogin" runat="server" class="divErrorHide">
                    <span id="spanErrLogin" runat="server" class="lblError"></span>
                </div>
            </div>
            <asp:Panel ID="pnlViewAgenda" runat="server">
                <div class="divRow" style="margin: auto; float: none; width: 900px;">
                    <div class="divRow">
                        <div class="divRow">
                            <div class="divRowLeft">
                                Committee Name :
                            </div>
                            <div class="divRowRight">
                                <div style="float: left; width: 175px">
                                    <asp:DropDownList ID="ddlCommittee" runat="server" Width="150px" AutoPostBack="true"
                                        OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                                    </asp:DropDownList>
                                    <span class="spanMandatory">*</span>
                                </div>
                                <div style="float: left; width: 250px">
                                    <asp:Label ID="lblNextScheduledMeeting" runat="server" Text="-" Visible="false"></asp:Label>
                                </div>
                            </div>
                        </div>
                        <div class="divRow">
                            <div class="divRowLeft">
                                Meeting No :
                            </div>
                            <div class="divRowRight">
                                <%--<asp:TextBox ID="txtMeeting" runat="server" Text="-" Enabled="false"></asp:TextBox>
                                <asp:HiddenField ID="hdnSearchMeetingId" runat="server" />--%>
                                <asp:DropDownList ID="ddlMeeting" runat="server" Width="150px" AutoPostBack="true"
                                    OnSelectedIndexChanged="ddlMeeting_SelectedIndexChanged" Enabled="true">
                                </asp:DropDownList>
                                <span class="spanMandatory">*</span>
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <asp:Button ID="btnAdd" runat="server" CssClass="button" Text="Add" OnClick="btnAdd_Click" />
                    </div>
                    <div class="divRow">
                        <div class="divRowGridScroll1">
                            <asp:GridView ID="grvAgenda" runat="server" SkinID="grvSkinNoPaging" AutoGenerateColumns="false"
                                CssClass="contentTable1" AllowSorting="true" CellPadding="4" DataKeyNames="AgendaId"
                                Font-Names="Verdana, Arial, Helvetica, sans-serif" Font-Size="X-Small" ForeColor="#333333"
                                GridLines="Horizontal" Height="32px" Width="100%" OnRowDataBound="grvAgenda_RowDataBound"
                                OnSorting="grvRecord_Sorting" OnRowCommand="grvAgenda_RowCommand">
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
                                            <asp:LinkButton ID="lnk3" runat="server" Text="MeetingNo" CommandName="Sort" Style="color: White"
                                                CommandArgument="StatusId"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblMeetingNo" runat="server" SkinID="lblskingen" Text='<%#Eval("MeetingNo") %>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
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
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                            Width="80px" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="SubjectNo">
                                        <HeaderTemplate>
                                            <asp:LinkButton ID="lnkSubjectNo" runat="server" Text="Subject No" CommandName="Sort"
                                                Style="color: White" CommandArgument="SubjectNo"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblSubjectNo" SkinID="lblSkinGen" Text='<%#Eval("SubjectNo")%>' runat="server" />
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                            Width="50px" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="DepartmentName">
                                        <HeaderTemplate>
                                            <asp:LinkButton ID="lnkDepartmentName" runat="server" Text="Department Name" CommandName="Sort"
                                                Style="color: White" CommandArgument="DepartmentName"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblDepartmentName" runat="server" SkinID="lblskingen" Text='<%#Eval("DepartmentName")%>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="SubjectTypeName">
                                        <HeaderTemplate>
                                            <asp:LinkButton ID="lnk4" runat="server" Text="Subject Type Name" CommandName="Sort"
                                                Style="color: White" CommandArgument="SubjectTypeName"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblSubjectTypeName" runat="server" SkinID="lblskingen" Text='<%#Eval("SubjectTypeName") %>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="ShortText">
                                        <HeaderTemplate>
                                            <asp:LinkButton ID="lnk5" runat="server" Text="Short Text" CommandName="Sort" Style="color: White"
                                                CommandArgument="ShortText"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblShortText" runat="server" SkinID="lblskingen" Text='<%#Eval("ShortText") %>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Justify" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="AgendaStatusName">
                                        <HeaderTemplate>
                                            <asp:LinkButton ID="lnk6" runat="server" Text="Agenda Status" CommandName="Sort"
                                                Style="color: White" CommandArgument="AgendaStatusName"></asp:LinkButton>
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <asp:Label ID="lblAgendaStatusName" runat="server" SkinID="lblskingen" Text='<%#Eval("AgendaStatusName") %>'></asp:Label>
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    <asp:TemplateField>
                                        <ItemTemplate>
                                            <asp:Button ID="btnEdit" Width="18px" Height="18px" CssClass="buttonEdit" ToolTip="Edit"
                                                CommandArgument='<%#Eval("AgendaId")%>' runat="server" CommandName="EditRec" />
                                        </ItemTemplate>
                                        <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                            Width="30px" />
                                    </asp:TemplateField>
                                    <asp:TemplateField>
                                        <ItemTemplate>
                                            <%if (Session["RoleCode"].ToString() == "controller")
                                          { %>
                                            <asp:Button ID="btnDelete" Width="18px" Height="18px" CssClass="buttonDelete" ToolTip="Delete"
                                                CommandArgument='<%#Eval("AgendaId")%>' runat="server" CommandName="DeleteRec"
                                                OnClientClick="return confirm('Are you sure you want to delete this Record?');" />
                                            <%
                                                } %>
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
            <asp:Panel ID="pnlEditAgenda" runat="server">
                <div class="divRow">
                    <div class="divRow">
                        <div class="divRowRight">
                            <div class="divRowLeft">
                                Agenda No :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtAgendaNo" runat="server" ReadOnly="true" Width="200px"></asp:TextBox>
                                <asp:HiddenField ID="hdnAgendaId" runat="server" />
                            </div>
                        </div>
                        <div class="divRowRight">
                            <div class="divRowLeft" style="width: 140px">
                                Subject No :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtSubjectNo" runat="server" Width="200px"></asp:TextBox>
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRowRight">
                            <div class="divRowLeft">
                                Committee Name :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtCommittee" runat="server" ReadOnly="true" Width="200px"></asp:TextBox>
                                <asp:HiddenField ID="hdnCommitteeId" runat="server" />
                            </div>
                        </div>
                        <div class="divRowRight">
                            <div class="divRowLeft" style="width: 140px">
                                Meeting No :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtMeetingNo" runat="server" ReadOnly="true" Width="200px"></asp:TextBox>
                                <asp:HiddenField ID="hdnMeetingId" runat="server" />
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRowRight">
                            <div class="divRowLeft">
                                Meeting Date :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtDateOfMeeting" runat="server" ReadOnly="true" Width="200px"></asp:TextBox>
                            </div>
                        </div>
                        <div class="divRowRight">
                            <div class="divRowLeft" style="width: 140px">
                                Department :
                            </div>
                            <div class="divRowRight">
                                <asp:Panel ID="pnlDepartment" runat="server">
                                    <asp:DropDownList ID="ddlDepartment" runat="server" Width="155px">
                                    </asp:DropDownList>
                                    <span class="spanMandatory">*</span>
                                </asp:Panel>
                                <asp:TextBox ID="txtDepartment" runat="server" ReadOnly="true" Width="200px"></asp:TextBox>
                                <asp:HiddenField ID="hdnDepartmentId" runat="server" />
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRowRight">
                            <div class="divRowLeft">
                                Subject Type :
                            </div>
                            <div class="divRowRight">
                                <asp:DropDownList ID="ddlSubjectType" runat="server" Width="200px">
                                </asp:DropDownList>
                                <span class="spanMandatory">*</span>
                            </div>
                        </div>
                        <div class="divRowRight">
                            <div class="divRowLeft">
                            </div>
                            <div class="divRowRight">
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRowLeft" style="width: 211px;">
                            Short Text :
                        </div>
                        <div class="divRowRight" style="width: 650px;">
                            <div style="float: left;">
                                <asp:TextBox ID="txtShortText" runat="server" ReadOnly="false" TextMode="MultiLine"
                                    Height="50px" Width="600px" Font-Names="Times" Font-Size="12pt"></asp:TextBox>
                            </div>
                            <div style="float: left; padding-left: 5px;">
                                <span class="spanMandatory">*</span>
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRowLeft" style="width: 211px;">
                            Agenda Type :
                        </div>
                        <div class="divRowRight" style="width: 650px;">
                            <asp:RadioButtonList ID="rdoAgendaType" runat="server" AutoPostBack="True" OnSelectedIndexChanged="rdoAgendaType_SelectedIndexChanged"
                                RepeatDirection="Horizontal">
                                <asp:ListItem Text="Entry" Value="Entry" Selected="True"></asp:ListItem>
                                <asp:ListItem Text="Upload" Value="Upload"></asp:ListItem>
                            </asp:RadioButtonList>
                            <asp:Panel ID="pnlUploadAgendaText" runat="server" Visible="false">
                                <asp:FileUpload ID="FileUploadAgendaText" runat="server" />
                                <span style="color: Red;">Note : Attach pdf files only.</span>
                            </asp:Panel>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRowLeft" style="width: 211px;">
                            Agenda Text :
                        </div>
                        <div class="divRowRight" style="width: 650px;">
                            <a id="aAgendaText" runat="server" target="_blank">View</a>
                            <FTB:FreeTextBox ID="ftxtAgendaText" runat="server" Height="100px" AllowHtmlMode="false" ShowTagPath="false"
                                    AutoGenerateToolbarsFromString="True" ButtonSet="Office2003"  
                                    ToolbarLayout="Bold,Italic,Underline|JustifyLeft,JustifyRight,JustifyCenter,JustifyFull;BulletedList,NumberedList,Indent,Outdent"
                                    ToolbarStyleConfiguration="Office2003">
                                </FTB:FreeTextBox>
                            <asp:Button ID="btnAddAgentaText" runat="server" Text="AddFile" OnClick="btnAddAgentaText_Click"
                                Style="visibility: hidden" />
                            <asp:TextBox ID="txtAgendaTextPath" runat="server" Width="150px" Style="visibility: hidden"></asp:TextBox>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRowLeft" style="width: 211px;">
                            Proposed Resolution :
                        </div>
                        <div class="divRowRight" style="width: 650px;">
                            <FTB:FreeTextBox ID="ftxtProposedResolution" runat="server" Height="100px"
                                    AllowHtmlMode="false" ShowTagPath="false"
                                    AutoGenerateToolbarsFromString="True" ButtonSet="Office2003" 
                                    ToolbarLayout="Bold,Italic,Underline|JustifyLeft,JustifyRight,JustifyCenter,JustifyFull;BulletedList,NumberedList,Indent,Outdent"
                                    ToolbarStyleConfiguration="Office2003">
                                </FTB:FreeTextBox>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRowLeft" style="width: 211px;">
                            Files to be Attached :
                        </div>
                        <div class="divRowRight" style="width: 650px;">
                            <asp:GridView ID="grvAttachedFiles" runat="server" AutoGenerateColumns="False" ShowHeader="False"
                                BackColor="#DEBA84" BorderColor="#DEBA84" BorderStyle="None" BorderWidth="1px"
                                CellPadding="3" CellSpacing="2">
                                <Columns>
                                    <asp:TemplateField>
                                        <ItemTemplate>
                                            <asp:CheckBox ID="cbAttach" runat="server" Checked="true" />
                                            <asp:HiddenField ID="hdnFilePath" runat="server" Value='<%#Eval("FilePathOrg") %>' />
                                        </ItemTemplate>
                                        <ItemStyle Width="50px" VerticalAlign="Middle" HorizontalAlign="Center" />
                                    </asp:TemplateField>
                                    <asp:TemplateField SortExpression="FilePath">
                                        <ItemTemplate>
                                            <a href='<%#Eval("FilePath") %>' target="_blank">
                                                <%#Eval("DisplayName") %>
                                            </a>
                                        </ItemTemplate>
                                    </asp:TemplateField>
                                </Columns>
                                <RowStyle BackColor="#FFF7E7" ForeColor="#8C4510" />
                                <FooterStyle BackColor="#F7DFB5" ForeColor="#8C4510" />
                                <PagerStyle ForeColor="#8C4510" HorizontalAlign="Center" />
                                <SelectedRowStyle BackColor="#738A9C" Font-Bold="True" ForeColor="White" />
                                <HeaderStyle BackColor="#A55129" Font-Bold="True" ForeColor="White" />
                            </asp:GridView>
                            <asp:FileUpload runat="server" ID="fuAttachment"></asp:FileUpload>
                            <span style="color: Red;">Note : Attach pdf files only.</span>
                            <asp:Button ID="btnAddFile" runat="server" Text="AddFile" OnClick="btnAddFile_Click"
                                Style="visibility: hidden" />
                        </div>
                    </div>
                    <asp:Panel ID="pnlManagerComments" runat="server">
                        <div class="divRow">
                            <div class="divRowLeft" style="width: 211px;">
                                Manager Comments :
                            </div>
                            <div class="divRowRight" style="width: 650px;">
                                <FTB:FreeTextBox ID="ftxtManagerComments" runat="server" Height="100px"
                                    AllowHtmlMode="false" ShowTagPath="false"
                                    AutoGenerateToolbarsFromString="True" ButtonSet="Office2003" 
                                    ToolbarLayout="Bold,Italic,Underline|JustifyLeft,JustifyRight,JustifyCenter,JustifyFull;BulletedList,NumberedList,Indent,Outdent"
                                    ToolbarStyleConfiguration="Office2003">
                                </FTB:FreeTextBox>
                            </div>
                        </div>
                    </asp:Panel>
                    <asp:Panel ID="pnlControllerComments" runat="server">
                        <div class="divRow">
                            <div class="divRowLeft" style="width: 211px;">
                                Controller Comments :
                            </div>
                            <div class="divRowRight" style="width: 650px;">
                                <FTB:FreeTextBox ID="ftxtControllerComments" runat="server" Height="100px"
                                    AllowHtmlMode="false" ShowTagPath="false"
                                    AutoGenerateToolbarsFromString="True" ButtonSet="Office2003" 
                                    ToolbarLayout="Bold,Italic,Underline|JustifyLeft,JustifyRight,JustifyCenter,JustifyFull;BulletedList,NumberedList,Indent,Outdent"
                                    ToolbarStyleConfiguration="Office2003">
                                </FTB:FreeTextBox>
                            </div>
                        </div>
                    </asp:Panel>
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
</asp:Content>
