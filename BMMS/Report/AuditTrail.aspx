<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="AuditTrail.aspx.cs" Inherits="BMMS.Report.AuditTrail" Title="Audit Trai" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <asp:Panel ID="pnlCommitteeMaster" runat="server">
                <div class="formContent">
                <div class="formPanel">
                    <div class="divHeader">
                    :: Audit Trai Report</div>
                    <div class="divRowFixed">
                    </div>
                    <div class="divRow">
                        <div class="divRow">
                            <div class="divRowLeft">
                                From Date :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtFromDate" runat="server" Width="100px" onfocus="this.blur();"
                                    TabIndex="-1"></asp:TextBox>
                                <asp:ImageButton runat="Server" ID="imgFromDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                <span class="spanMandatory">*</span>
                                <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender2" runat="server"
                                    TargetControlID="txtFromDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                    PopupButtonID="imgFromDate">
                                </cc1:CalendarExtender>
                            </div>
                        </div>
                        <div class="divRow">
                            <div class="divRowLeft">
                                To Date :
                            </div>
                            <div class="divRowRight">
                                <asp:TextBox ID="txtToDate" runat="server" Width="100px" onfocus="this.blur();" TabIndex="-1"></asp:TextBox>
                                <asp:ImageButton runat="Server" ID="imgToDate" Width="18px" ImageUrl="~/Images/Common/calendar.png" />
                                <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender1" runat="server"
                                    TargetControlID="txtToDate" Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right"
                                    PopupButtonID="imgToDate">
                                </cc1:CalendarExtender>
                            </div>
                        </div>
                        <div class="divRow">
                            <div class="divRowLeft">
                                User Name :
                            </div>
                            <div class="divRowRight">
                                <asp:DropDownList ID="ddlUsers" runat="server" Width="150px" DataTextField="LoginName"
                                    DataValueField="UserId">
                                </asp:DropDownList>
                                <br />
                                <br />
                                <asp:Button ID="btnSubmit" runat="server" CssClass="button" Text="Submit" OnClick="btnSubmit_Click" />
                            </div>
                        </div>
                    </div>
                    <div class="divRow" style="height: 300px; overflow: auto;">
                        <asp:GridView ID="grvAuditTrail" runat="server" AutoGenerateColumns="false" CssClass="contentTable1"
                            AllowSorting="true" CellPadding="4" DataKeyNames="Audit_Trail_Maser_Id" Font-Names="Verdana, Arial, Helvetica, sans-serif"
                            Font-Size="X-Small" ForeColor="#333333" GridLines="Horizontal" Height="32px"
                            Width="100%" OnSorting="grvRecord_Sorting">
                            <HeaderStyle CssClass="contentTableHeader" HorizontalAlign="Center" Font-Bold="true" />
                            <Columns>
                                <asp:TemplateField HeaderText="S.No.">
                                    <ItemTemplate>
                                        <%# Container.DataItemIndex+1 + "."%>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center"
                                        Width="10px" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="Audit_Table">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Audit Table" CommandName="Sort" Style="color: White"
                                            CommandArgument="Audit_Table"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblAudit_Table" runat="server" SkinID="lblskingen" Text='<%#Eval("Audit_Table")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="Key_Field">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Key Field" CommandName="Sort" Style="color: White"
                                            CommandArgument="Key_Field"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblKey_Field" SkinID="lblSkinGen" Text='<%#Eval("Key_Field")%>' runat="server" />
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="Key_Value">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Key Value" CommandName="Sort" Style="color: White"
                                            CommandArgument="Key_Value"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblKey_Value" runat="server" SkinID="lblskingen" Text='<%#Eval("Key_Value")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="Field_Name">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Field Name" CommandName="Sort" Style="color: White"
                                            CommandArgument="Field_Name"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblField_Name" runat="server" SkinID="lblskingen" Text='<%#Eval("Field_Name")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="Update_By_Name">
                                    <HeaderTemplate>
                                        <asp:LinkButton runat="server" Text="Update By" CommandName="Sort" Style="color: White"
                                            CommandArgument="Update_By_Name"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblUpdate_By_Name" runat="server" SkinID="lblskingen" Text='<%#Eval("Update_By_Name")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
                                </asp:TemplateField>
                                <asp:TemplateField SortExpression="Update_On">
                                    <HeaderTemplate>
                                        <asp:LinkButton ID="LinkButton1" runat="server" Text="Update On" CommandName="Sort"
                                            Style="color: White" CommandArgument="Update_On"></asp:LinkButton>
                                    </HeaderTemplate>
                                    <ItemTemplate>
                                        <asp:Label ID="lblUpdate_On" runat="server" SkinID="lblskingen" Text='<%#Eval("Update_On")%>'></asp:Label>
                                    </ItemTemplate>
                                    <ItemStyle CssClass="contentTabletd" VerticalAlign="Middle" HorizontalAlign="Left" />
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
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
