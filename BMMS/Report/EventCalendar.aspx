<%@ Page Language="C#" MasterPageFile="~/MasterPage/Main.Master" AutoEventWireup="true"
    Codebehind="EventCalendar.aspx.cs" Inherits="BMMS.Report.EventCalendar" Title="Event Calendar" %>

<%@ Register Assembly="AjaxControlToolkit" Namespace="AjaxControlToolkit" TagPrefix="cc1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <asp:UpdatePanel ID="UpdatePanel1" runat="server">
        <ContentTemplate>
            <asp:Panel ID="pnlEventCalendar" runat="server">
                <div class="formContent">
                <div class="formPanel">
                    <div class="divHeader">
                    :: Event Calendar</div>
                    <div class="divRowFixed"></div>
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
                                <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender2" runat="server" TargetControlID="txtFromDate"
                                    Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right" PopupButtonID="imgFromDate">
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
                                <cc1:CalendarExtender CssClass="cal_Theme1" ID="CalendarExtender1" runat="server" TargetControlID="txtToDate"
                                    Animated="true" Format="dd-MMM-yyyy" PopupPosition="Right" PopupButtonID="imgToDate">
                                </cc1:CalendarExtender>
                            </div>
                        </div>
                        <div class="divRow">
                            <div class="divRowLeft">
                                Sort Option :
                            </div>
                            <div class="divRowRight">
                                <asp:RadioButtonList ID="rdoSortOption" runat="server" AutoPostBack="True" RepeatDirection="Horizontal">
                                    <asp:ListItem Text="Committee" Value="Committee" Selected="True"></asp:ListItem>
                                    <asp:ListItem Text="Meeting Date" Value="MeetingDate"></asp:ListItem>
                                </asp:RadioButtonList>
                                <br />
                                <br />
                                <asp:Button ID="btnSubmit" runat="server" CssClass="button" Text="Submit" OnClick="btnSubmit_Click" />
                            </div>
                        </div>
                    </div>
                    <div class="divRow">
                        <asp:GridView ID="grvEventCalendar" SkinID="grvCommon" runat="server" GridLines="Both"
                            AutoGenerateColumns="False" RowStyle-Height="75px" Width="85%" HeaderStyle-Height="45px"
                            CssClass="contentTable1" AllowSorting="true" CellPadding="4" DataKeyNames="MeetingId"
                            Font-Names="Verdana, Arial, Helvetica, sans-serif" Font-Size="X-Small" ForeColor="#333333">
                            <HeaderStyle CssClass="contentTableHeader" HorizontalAlign="Center" Font-Bold="true" />
                            <Columns>
                                <asp:TemplateField HeaderText="Days ------- Weeks">
                                    <ItemTemplate>
                                        <%# Container.DataItemIndex+1 + " Week"%>
                                    </ItemTemplate>
                                    <ItemStyle Width="11%" VerticalAlign="Middle" HorizontalAlign="Center" Font-Bold="true"
                                        ForeColor="DarkGreen" />
                                </asp:TemplateField>
                                <asp:TemplateField HeaderText="Sunday">
                                    <ItemTemplate>
                                        <%#Eval("Sunday", "{0:dd-MMM-yyyy (ddd)}")%>
                                    </ItemTemplate>
                                    <ItemStyle Width="11%" VerticalAlign="Middle" HorizontalAlign="Center" ForeColor="red"
                                        Font-Bold="true" />
                                </asp:TemplateField>
                                <asp:TemplateField HeaderText="Monday">
                                    <ItemTemplate>
                                        <%#Eval("Monday", "{0:dd-MMM-yyyy (ddd)}")%>
                                    </ItemTemplate>
                                    <ItemStyle Width="13%" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField HeaderText="Tuesday">
                                    <ItemTemplate>
                                        <%#Eval("Tuesday", "{0:dd-MMM-yyyy (ddd)}")%>
                                    </ItemTemplate>
                                    <ItemStyle Width="13%" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField HeaderText="Wednesday">
                                    <ItemTemplate>
                                        <%#Eval("Wednesday", "{0:dd-MMM-yyyy (ddd)}")%>
                                    </ItemTemplate>
                                    <ItemStyle Width="13%" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField HeaderText="Thursday">
                                    <ItemTemplate>
                                        <%#Eval("Thursday", "{0:dd-MMM-yyyy (ddd)}")%>
                                    </ItemTemplate>
                                    <ItemStyle Width="13%" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField HeaderText="Friday">
                                    <ItemTemplate>
                                        <%#Eval("Friday", "{0:dd-MMM-yyyy (ddd)}")%>
                                    </ItemTemplate>
                                    <ItemStyle Width="13%" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                                <asp:TemplateField HeaderText="Saturday">
                                    <ItemTemplate>
                                        <%#Eval("Saturday", "{0:dd-MMM-yyyy (ddd)}")%>
                                    </ItemTemplate>
                                    <ItemStyle Width="13%" VerticalAlign="Middle" HorizontalAlign="Center" />
                                </asp:TemplateField>
                            </Columns>
                        </asp:GridView>
                    </div>
                </div>
                </div>
            </asp:Panel>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
