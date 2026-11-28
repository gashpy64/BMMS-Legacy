using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Globalization;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using BMMSBAL;

namespace BMMS.Controls
{
    /// <summary>
    /// The rich-text editor of step A2a (in place of FreeTextBox): a toolbar (bold, italic, underline, bulleted and
    /// numbered list, four alignments, undo, redo) over a contenteditable box, driven by JScript/RichTextEditor.js.
    ///
    /// The text travels in one hidden field as Base64 of its UTF-8 bytes (RichTextPost), so the post holds no
    /// markup and request validation stays on. The server renders the cleaned text into the box and the same
    /// text into the field; the script replaces the field only after a real edit, so an untouched editor posts
    /// back exactly what the server rendered. Every posted value is cleaned with HtmlCleaner.Clean; text that
    /// shows nothing (HtmlCleaner.IsBlank) becomes empty text.
    ///
    /// Read-only (ReadOnly, or not enabled): the text is shown, nothing is posted, and any posted value is
    /// ignored. A hidden or read-only editor keeps its text in view state, as FreeTextBox did; an editable,
    /// visible one does not (the hidden field carries it), so the text is not sent twice.
    ///
    /// Limits (RichTextLimits, from Web.config): the script refuses to post over the limit; the page's save,
    /// attach and upload handlers call IsTooLong(Page) first and refuse with RichTextLimits.TooLongMessage.
    /// An editor over the limit keeps the posted text, so nothing typed is lost.
    /// </summary>
    [ToolboxData("<{0}:RichTextEditor runat=\"server\" />")]
    public class RichTextEditor : WebControl, IPostBackDataHandler
    {
        private const string PageListKey = "BMMS.Controls.RichTextEditor.List";

        private string text = string.Empty;
        private bool tooLong;
        private int postedLength;

        public RichTextEditor()
            : base(HtmlTextWriterTag.Div)
        {
        }

        #region Properties
        // The cleaned HTML; never null
        public string Text
        {
            get { return text; }
            set { text = value ?? string.Empty; }
        }

        public bool ReadOnly
        {
            get { object o = ViewState["ReadOnly"]; return o != null && (bool)o; }
            set { ViewState["ReadOnly"] = value; }
        }

        // The name screen readers announce for the box (the label beside it on the page)
        public string Label
        {
            get { return (string)ViewState["Label"] ?? string.Empty; }
            set { ViewState["Label"] = value; }
        }

        // True when the value posted in this request is over RichTextLimits.MaxChars
        public bool TooLong
        {
            get { return tooLong; }
        }

        // Characters of HTML posted in this request (0 when nothing was posted)
        public int PostedLength
        {
            get { return postedLength; }
        }

        private bool IsEditable
        {
            get { return !ReadOnly && IsEnabled; }
        }
        #endregion

        #region IsTooLong
        // True when an editor of the page posted more than RichTextLimits.MaxChars, or all editors together more
        // than RichTextLimits.MaxTotalChars. Called first by every handler that saves or uploads.
        public static bool IsTooLong(Page page)
        {
            List<RichTextEditor> editors = page == null ? null : page.Items[PageListKey] as List<RichTextEditor>;
            if (editors == null)
                return false;

            long total = 0;
            foreach (RichTextEditor editor in editors)
            {
                if (editor.tooLong)
                    return true;
                total += editor.postedLength;
            }

            return total > RichTextLimits.MaxTotalChars;
        }
        #endregion

        #region OnInit
        protected override void OnInit(EventArgs e)
        {
            base.OnInit(e);

            List<RichTextEditor> editors = Page.Items[PageListKey] as List<RichTextEditor>;
            if (editors == null)
            {
                editors = new List<RichTextEditor>();
                Page.Items[PageListKey] = editors;
            }
            editors.Add(this);

            // The hidden field is named after UniqueID, so LoadPostData runs when it is posted
            Page.RegisterRequiresPostBack(this);
        }
        #endregion

        #region View state
        protected override object SaveViewState()
        {
            object baseState = base.SaveViewState();
            bool keepText = !Visible || !IsEditable;

            return new Triplet(baseState, keepText, keepText ? text : null);
        }

        protected override void LoadViewState(object savedState)
        {
            Triplet state = savedState as Triplet;
            if (state == null)
            {
                base.LoadViewState(savedState);
                return;
            }

            base.LoadViewState(state.First);

            if (state.Second is bool && (bool)state.Second)
                text = (state.Third as string) ?? string.Empty;
        }
        #endregion

        #region IPostBackDataHandler
        public bool LoadPostData(string postDataKey, NameValueCollection postCollection)
        {
            if (!IsEditable)
                return false;

            string posted = postCollection[postDataKey];
            if (posted == null)
                return false;

            string html;
            RichTextPostResult result = RichTextPost.Decode(posted, RichTextLimits.MaxChars, out html);

            switch (result)
            {
                case RichTextPostResult.Empty:
                    text = string.Empty;
                    postedLength = 0;
                    break;

                case RichTextPostResult.Text:
                case RichTextPostResult.TooLong:
                    tooLong = result == RichTextPostResult.TooLong;
                    postedLength = html.Length;
                    string cleaned = HtmlCleaner.Clean(html);
                    text = HtmlCleaner.IsBlank(cleaned) ? string.Empty : cleaned;
                    break;

                default:
                    // Not written by the script: refused like any other bad request (Application_Error logs it)
                    throw new HttpException(400, "The value of the rich-text field " + UniqueID + " could not be read.");
            }

            return false;
        }

        public void RaisePostDataChangedEvent()
        {
        }
        #endregion

        #region Render
        protected override void AddAttributesToRender(HtmlTextWriter writer)
        {
            writer.AddAttribute(HtmlTextWriterAttribute.Id, ClientID);
            writer.AddAttribute(HtmlTextWriterAttribute.Class, "rte" + (IsEditable ? string.Empty : " rte-readonly")
                + (string.IsNullOrEmpty(CssClass) ? string.Empty : " " + CssClass));

            if (!Width.IsEmpty)
                writer.AddStyleAttribute(HtmlTextWriterStyle.Width, Width.ToString(CultureInfo.InvariantCulture));

            if (IsEditable)
            {
                writer.AddAttribute("data-rte", "1");
                writer.AddAttribute("data-rte-max", RichTextLimits.MaxChars.ToString(CultureInfo.InvariantCulture));
                writer.AddAttribute("data-rte-max-total", RichTextLimits.MaxTotalChars.ToString(CultureInfo.InvariantCulture));
                writer.AddAttribute("data-rte-too-long", RichTextLimits.TooLongMessage);
            }
        }

        protected override void RenderContents(HtmlTextWriter writer)
        {
            // Cleaned again here: whatever a page put into Text, the box only ever gets allow-list HTML
            string html = HtmlCleaner.Clean(text);
            string boxId = ClientID + "_box";

            if (IsEditable)
                RenderToolbar(writer, boxId);

            // Written without indenting: no white space may be added inside the editable box
            writer.WriteBeginTag("div");
            writer.WriteAttribute("id", boxId);
            writer.WriteAttribute("class", "rte-box");
            writer.WriteAttribute("role", "textbox");
            writer.WriteAttribute("aria-multiline", "true");
            if (Label.Length > 0)
                writer.WriteAttribute("aria-label", Label, true);
            if (IsEditable)
            {
                writer.WriteAttribute("contenteditable", "true");
                writer.WriteAttribute("spellcheck", "true");
                writer.WriteAttribute("data-rte-len", html.Length.ToString(CultureInfo.InvariantCulture));
            }
            else
            {
                writer.WriteAttribute("aria-readonly", "true");
                writer.WriteAttribute("tabindex", "0");
            }
            if (!Height.IsEmpty)
                writer.WriteAttribute("style", "height:" + Height.ToString(CultureInfo.InvariantCulture) + ";");
            writer.Write(HtmlTextWriter.TagRightChar);
            writer.Write(html);
            writer.WriteEndTag("div");

            if (!IsEditable)
                return;

            writer.AddAttribute(HtmlTextWriterAttribute.Type, "hidden");
            writer.AddAttribute(HtmlTextWriterAttribute.Name, UniqueID);
            writer.AddAttribute(HtmlTextWriterAttribute.Id, ClientID + "_value");
            writer.AddAttribute(HtmlTextWriterAttribute.Value, RichTextPost.Encode(html));
            writer.RenderBeginTag(HtmlTextWriterTag.Input);
            writer.RenderEndTag();

            // Without indenting: the CSS hides the line while it is :empty
            writer.WriteBeginTag("div");
            writer.WriteAttribute("id", ClientID + "_msg");
            writer.WriteAttribute("class", "rte-message");
            writer.WriteAttribute("role", "alert");
            writer.Write(HtmlTextWriter.TagRightChar);
            if (tooLong)
                writer.Write(HttpUtility.HtmlEncode(RichTextLimits.TooLongMessage));
            writer.WriteEndTag("div");
        }

        private void RenderToolbar(HtmlTextWriter writer, string boxId)
        {
            writer.AddAttribute(HtmlTextWriterAttribute.Class, "rte-toolbar");
            writer.AddAttribute("role", "toolbar");
            writer.AddAttribute("aria-label", Label.Length > 0 ? Label + " formatting" : "Formatting");
            writer.AddAttribute("aria-controls", boxId);
            writer.RenderBeginTag(HtmlTextWriterTag.Div);

            RenderButton(writer, "bold", "Bold (Ctrl+B)", true, "<b>B</b>");
            RenderButton(writer, "italic", "Italic (Ctrl+I)", true, "<i>I</i>");
            RenderButton(writer, "underline", "Underline (Ctrl+U)", true, "<u>U</u>");
            RenderSeparator(writer);
            RenderButton(writer, "insertUnorderedList", "Bulleted list", true, Icon("M3 4h2v2H3zM7 4h10v2H7zM3 9h2v2H3zM7 9h10v2H7zM3 14h2v2H3zM7 14h10v2H7z"));
            RenderButton(writer, "insertOrderedList", "Numbered list", true, Icon("M3 3h2v4H4V4H3zM7 4h10v2H7zM3 9h3v1H4v1h2v1H3zM7 9h10v2H7zM3 14h3v4H3v-1h2v-.5H4v-1h1V15H3zM7 14h10v2H7z"));
            RenderSeparator(writer);
            RenderButton(writer, "justifyLeft", "Align left", true, Icon("M3 4h14v2H3zM3 8h9v2H3zM3 12h14v2H3zM3 16h9v2H3z"));
            RenderButton(writer, "justifyCenter", "Align centre", true, Icon("M3 4h14v2H3zM5.5 8h9v2h-9zM3 12h14v2H3zM5.5 16h9v2h-9z"));
            RenderButton(writer, "justifyRight", "Align right", true, Icon("M3 4h14v2H3zM8 8h9v2H8zM3 12h14v2H3zM8 16h9v2H8z"));
            RenderButton(writer, "justifyFull", "Justify", true, Icon("M3 4h14v2H3zM3 8h14v2H3zM3 12h14v2H3zM3 16h14v2H3z"));
            RenderSeparator(writer);
            RenderButton(writer, "undo", "Undo (Ctrl+Z)", false, Icon("M8 5V2L3 7l5 5V9h4a3 3 0 0 1 0 6H8v2h4a5 5 0 0 0 0-10z"));
            RenderButton(writer, "redo", "Redo (Ctrl+Y)", false, Icon("M12 5V2l5 5-5 5V9H8a3 3 0 0 0 0 6h4v2H8A5 5 0 0 1 8 7z"));

            writer.RenderEndTag();
        }

        // A toolbar button; toggles carry aria-pressed. The label is for screen readers and the tooltip.
        private static void RenderButton(HtmlTextWriter writer, string command, string label, bool toggle, string content)
        {
            writer.AddAttribute(HtmlTextWriterAttribute.Type, "button");
            writer.AddAttribute(HtmlTextWriterAttribute.Class, "rte-button");
            writer.AddAttribute("data-rte-cmd", command);
            writer.AddAttribute("aria-label", label);
            writer.AddAttribute(HtmlTextWriterAttribute.Title, label);
            writer.AddAttribute(HtmlTextWriterAttribute.Tabindex, "-1");
            if (toggle)
                writer.AddAttribute("aria-pressed", "false");
            writer.RenderBeginTag(HtmlTextWriterTag.Button);
            writer.Write(content);
            writer.RenderEndTag();
        }

        private static void RenderSeparator(HtmlTextWriter writer)
        {
            writer.AddAttribute(HtmlTextWriterAttribute.Class, "rte-separator");
            writer.AddAttribute("aria-hidden", "true");
            writer.RenderBeginTag(HtmlTextWriterTag.Span);
            writer.RenderEndTag();
        }

        private static string Icon(string path)
        {
            return "<svg viewBox=\"0 0 20 20\" width=\"16\" height=\"16\" aria-hidden=\"true\" focusable=\"false\"><path d=\"" + path + "\" fill=\"currentColor\"/></svg>";
        }
        #endregion
    }
}
