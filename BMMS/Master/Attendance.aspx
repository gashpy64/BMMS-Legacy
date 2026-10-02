<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="Attendance.aspx.cs" Inherits="BMMS.Master.Attendance" Title="Untitled Page"
    ValidateRequest="false" %>

<%@ Register Assembly="FreeTextBox" Namespace="FreeTextBoxControls" TagPrefix="FTB" %>
<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="formContent">
    <div class="formPanel">
        <div class="divHeader">
        :: Attendance</div>
        <div class="divRowFixed">
        </div>
        <div class="divRow" style="height: 25px">
            <div id="divErrLogin" runat="server" class="divErrorHide">
                <span id="spanErrLogin" runat="server" class="lblError"></span>
            </div>
        </div>
        <div class="divRow">
            <div class="divRow">
                <div class="divRowLeft" style="width: 30%;">
                    Committee Name :
                </div>
                <div class="divRowRight" style="width: 65%;">
                    <asp:DropDownList ID="ddlCommittee" runat="server" Width="150px" AutoPostBack="true"
                        OnSelectedIndexChanged="ddlCommittee_SelectedIndexChanged">
                    </asp:DropDownList>
                    <span class="spanMandatory">*</span>
                </div>
            </div>
            <div class="divRow">
                <div class="divRowLeft" style="width: 30%;">
                    Meeting No :
                </div>
                <div class="divRowRight" style="width: 65%;">
                    <asp:DropDownList ID="ddlMeeting" runat="server" Width="150px" AutoPostBack="true"
                        OnSelectedIndexChanged="ddlMeeting_SelectedIndexChanged">
                    </asp:DropDownList>
                    <span class="spanMandatory">*</span>
                    <br />
                </div>
            </div>
            <div class="divRow">
                <div class="divRowLeft" style="width: 30%;">
                    Chairman Name :
                </div>
                <div class="divRowRight" style="width: 65%;">
                    <asp:DropDownList ID="ddlChairmanName" runat="server" Width="150px">
                    </asp:DropDownList>
                    <span class="spanMandatory">*</span>
                    <br />
                </div>
            </div>
            <div class="divRow">
                <asp:Panel ID="pnlAttendance" runat="server">
                    <div class="divRow">
                        <div class="divRowLeft" style="width: 30%;">
                            Committee Members :
                        </div>
                        <div class="divRowRight" style="width: 65%;">
                            <div>
                                <asp:GridView ID="grvCommitteeMember" runat="server" Width="600px" AutoGenerateColumns="False"
                                    OnRowDataBound="grvCommitteeMember_RowDataBound" CellPadding="5">
                                    <HeaderStyle VerticalAlign="Middle" HorizontalAlign="Center" />
                                    <Columns>
                                        <asp:TemplateField HeaderStyle-ForeColor="black" HeaderText="Select">
                                            <HeaderTemplate>
                                                <asp:CheckBox ID="cbSelectAll" runat="server" />
                                            </HeaderTemplate>
                                            <ItemTemplate>
                                                <asp:CheckBox ID="cbMember" runat="server" />
                                            </ItemTemplate>
                                            <ItemStyle Width="50px" VerticalAlign="Middle" HorizontalAlign="Center" />
                                            <ItemStyle VerticalAlign="Middle" HorizontalAlign="Center" />
                                        </asp:TemplateField>
                                        <asp:TemplateField HeaderText="Member Name">
                                            <ItemTemplate>
                                                <asp:Label ID="lblMemberName" runat="server" Text='<% #Eval("MemberName") %>' Visible="true"></asp:Label>
                                                <asp:Label ID="lblMemberId" runat="server" Text='<% #Eval("MemberId") %>' Visible="false"></asp:Label>
                                            </ItemTemplate>
                                            <ItemStyle VerticalAlign="Middle" HorizontalAlign="left" />
                                        </asp:TemplateField>
                                        <asp:TemplateField HeaderText="Designation Name">
                                            <ItemTemplate>
                                                <asp:Label ID="lblDesignationName" runat="server" Text='<% #Eval("DesignationName") %>'
                                                    Visible="true"></asp:Label>
                                            </ItemTemplate>
                                            <ItemStyle Width="150px" VerticalAlign="Middle" HorizontalAlign="left" />
                                        </asp:TemplateField>
                                        <asp:TemplateField HeaderText="Member Type Name">
                                            <ItemTemplate>
                                                <asp:Label ID="lblMemberTypeName" runat="server" Text='<% #Eval("MemberTypeName") %>'
                                                    Visible="true"></asp:Label>
                                            </ItemTemplate>
                                            <ItemStyle Width="150px" VerticalAlign="Middle" HorizontalAlign="left" />
                                        </asp:TemplateField>
                                    </Columns>
                                </asp:GridView>
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <div class="divRowLeft" style="width: 30%;">
                            Meeting Members :
                        </div>
                        <div class="divRowRight" style="width: 65%;">
                            <div>
                                <asp:GridView ID="grvMeetingMember" runat="server" Width="600px" AutoGenerateColumns="False"
                                    OnRowDataBound="grvMeetingMember_RowDataBound" CellPadding="5">
                                    <HeaderStyle VerticalAlign="Middle" HorizontalAlign="Center" />
                                    <Columns>
                                        <asp:TemplateField HeaderStyle-ForeColor="black" HeaderText="Select">
                                            <HeaderTemplate>
                                                <asp:CheckBox ID="cbSelectAll" runat="server" />
                                            </HeaderTemplate>
                                            <ItemTemplate>
                                                <asp:CheckBox ID="cbMember" runat="server" />
                                            </ItemTemplate>
                                            <ItemStyle Width="50px" VerticalAlign="Middle" HorizontalAlign="Center" />
                                        </asp:TemplateField>
                                        <asp:TemplateField HeaderText="Member Name">
                                            <ItemTemplate>
                                                <asp:Label ID="lblMemberName" runat="server" Text='<% #Eval("MemberName") %>' Visible="true"></asp:Label>
                                                <asp:Label ID="lblMemberId" runat="server" Text='<% #Eval("MemberId") %>' Visible="false"></asp:Label>
                                            </ItemTemplate>
                                            <ItemStyle VerticalAlign="Middle" HorizontalAlign="Left" />
                                        </asp:TemplateField>
                                        <asp:TemplateField HeaderText="Designation Name">
                                            <ItemTemplate>
                                                <asp:Label ID="lblDesignationName" runat="server" Text='<% #Eval("DesignationName") %>'
                                                    Visible="true"></asp:Label>
                                            </ItemTemplate>
                                            <ItemStyle Width="150px" VerticalAlign="Middle" HorizontalAlign="left" />
                                        </asp:TemplateField>
                                        <asp:TemplateField HeaderText="Member Type Name">
                                            <ItemTemplate>
                                                <asp:Label ID="lblMemberTypeName" runat="server" Text='<% #Eval("MemberTypeName") %>'
                                                    Visible="true"></asp:Label>
                                            </ItemTemplate>
                                            <ItemStyle Width="150px" VerticalAlign="Middle" HorizontalAlign="left" />
                                        </asp:TemplateField>
                                    </Columns>
                                </asp:GridView>
                            </div>
                            <br />
                            <br />
                            <asp:Button ID="btnUpdate" runat="server" CssClass="button" Text="Update" OnClick="btnUpdate_Click"
                                OnClientClick="return confirm('Do you want to Update Attendance?');" />
                            <asp:Button ID="btnCancel" runat="server" CssClass="button" Text="Cancel" OnClick="btnCancel_Click" />
                        </div>
                    </div>
                </asp:Panel>
            </div>
        </div>
    </div>
    </div>
    <script type="text/javascript">
                 function SelectAllCommitteeMember(id)
                    {
                        //get reference of GridView control
                        var grid = document.getElementById("<%= grvCommitteeMember.ClientID %>");
                        //variable to contain the cell of the grid
                        var cell;
                        
                        if (grid.rows.length > 0)
                        {
                            //loop starts from 1. rows[0] points to the header.
                            for (i=1; i<grid.rows.length; i++)
                            {
                                //get the reference of first column
                                cell = grid.rows[i].cells[0];
                                
                                //loop according to the number of childNodes in the cell
                                for (j=0; j<cell.childNodes.length; j++)
                                {           
                                    //if childNode type is CheckBox                 
                                    if (cell.childNodes[j].type =="checkbox")
                                    {
                                    //assign the status of the Select All checkbox to the cell checkbox within the grid
                                        cell.childNodes[j].checked = document.getElementById(id).checked;
                                    }
                                }
                            }
                        }
                    }
    </script>

    <script type="text/javascript">
                 function SelectAllMeetingMember(id)
                    {
                        //get reference of GridView control
                        var grid = document.getElementById("<%= grvMeetingMember.ClientID %>");
                        //variable to contain the cell of the grid
                        var cell;
                        
                        if (grid.rows.length > 0)
                        {
                            //loop starts from 1. rows[0] points to the header.
                            for (i=1; i<grid.rows.length; i++)
                            {
                                //get the reference of first column
                                cell = grid.rows[i].cells[0];
                                
                                //loop according to the number of childNodes in the cell
                                for (j=0; j<cell.childNodes.length; j++)
                                {           
                                    //if childNode type is CheckBox                 
                                    if (cell.childNodes[j].type =="checkbox")
                                    {
                                    //assign the status of the Select All checkbox to the cell checkbox within the grid
                                        cell.childNodes[j].checked = document.getElementById(id).checked;
                                    }
                                }
                            }
                        }
                    }
    </script>

</asp:Content>
