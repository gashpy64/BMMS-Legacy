using System;
using System.Collections;
using System.Data;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Web;
using iTextSharp.text;
using iTextSharp.text.pdf;

namespace BMMSBAL
{
    // The font of the PDF exports (step U1b): Noto Serif (~/Fonts/Pdf, SIL Open Font License), embedded with
    // Unicode encoding (Identity-H), in place of the built-in Times and Helvetica, which only have the 1252
    // code page and left the rupee sign out. Noto Serif has Latin, Greek, Cyrillic and the rupee sign; a
    // character it does not have prints as ? (Printable). It has no Tamil or Devanagari, and iTextSharp 4 cannot
    // join their letters even with a font that has them, so a PDF export with Tamil or Hindi text is not made:
    // the page checks HasIndicText first and shows IndicTextMessage instead (Word export and Print show it).
    public static class PdfFonts
    {
        public const string IndicTextMessage = "Tamil or Hindi text cannot be printed correctly in a PDF";

        private static readonly object fontLock = new object();
        private static BaseFont regular, bold, italic, boldItalic;
        private static readonly FontFactoryImp htmlFontFactory = new NotoFontFactory();

        #region Fonts
        // A font of this size and style (Font.NORMAL, BOLD, ITALIC, BOLDITALIC, with UNDERLINE or STRIKETHRU);
        // bold and italic are the Noto Serif Bold / Italic files, not simulated
        public static Font Get(float Size, int Style)
        {
            return Get(Size, Style, null);
        }

        public static Font Get(float Size, int Style, Color FontColor)
        {
            if (Style == Font.UNDEFINED)
                Style = Font.NORMAL;
            if (Size == Font.UNDEFINED)
                Size = 12;

            LoadFonts();

            BaseFont baseFont;
            switch (Style & Font.BOLDITALIC)
            {
                case Font.BOLD:
                    baseFont = bold;
                    break;
                case Font.ITALIC:
                    baseFont = italic;
                    break;
                case Font.BOLDITALIC:
                    baseFont = boldItalic;
                    break;
                default:
                    baseFont = regular;
                    break;
            }

            return new Font(baseFont, Size, Style & ~Font.BOLDITALIC, FontColor);
        }

        // The folder of the font files: <site>\Fonts\Pdf
        public static string FontFolder
        {
            get { return Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Fonts\\Pdf"); }
        }

        private static void LoadFonts()
        {
            if (boldItalic != null)
                return;

            lock (fontLock)
            {
                if (boldItalic != null)
                    return;

                regular = LoadFont("NotoSerif-Regular.ttf");
                bold = LoadFont("NotoSerif-Bold.ttf");
                italic = LoadFont("NotoSerif-Italic.ttf");
                boldItalic = LoadFont("NotoSerif-BoldItalic.ttf");
            }
        }

        private static BaseFont LoadFont(string FileName)
        {
            string path = Path.Combine(FontFolder, FileName);
            if (!File.Exists(path))
                throw new FileNotFoundException("The PDF font file is missing: " + path, path);

            return BaseFont.CreateFont(path, BaseFont.IDENTITY_H, BaseFont.EMBEDDED);
        }
        #endregion

        #region Text
        // The text with each character the font does not have replaced by ? (iTextSharp would leave it out
        // without a sign). Line breaks and tabs are kept.
        public static string Printable(string Text)
        {
            if (string.IsNullOrEmpty(Text))
                return Text == null ? string.Empty : Text;

            LoadFonts();

            StringBuilder sb = null;
            for (int i = 0; i < Text.Length; i++)
            {
                char c = Text[i];
                bool keep = c < ' ' || regular.CharExists(c);

                if (char.IsHighSurrogate(c) && i + 1 < Text.Length && char.IsLowSurrogate(Text[i + 1]))
                {
                    // Outside the Basic Multilingual Plane: not in the font; one ? for the pair
                    if (sb == null)
                        sb = new StringBuilder(Text, 0, i, Text.Length);
                    sb.Append('?');
                    i++;
                    continue;
                }

                if (!keep && sb == null)
                    sb = new StringBuilder(Text, 0, i, Text.Length);
                if (sb != null)
                    sb.Append(keep ? c : '?');
            }

            return sb == null ? Text : sb.ToString();
        }

        // HTML for HTMLWorker: Printable, and a numeric character reference (&#8377; &#x20B9;) of a character
        // the font does not have also becomes ?. The markup itself is ASCII and is kept.
        public static string PrintableHtml(string Html)
        {
            string html = Printable(Html);

            return Regex.Replace(html, "&#(x[0-9a-fA-F]+|[0-9]+);", delegate (Match m)
            {
                string value = m.Groups[1].Value;
                int code;
                bool parsed = value.StartsWith("x", StringComparison.OrdinalIgnoreCase)
                    ? int.TryParse(value.Substring(1), System.Globalization.NumberStyles.HexNumber, null, out code)
                    : int.TryParse(value, out code);

                if (!parsed || code < 0x20 || (code <= 0xFFFF && regular.CharExists((char)code)))
                    return m.Value;
                return "?";
            });
        }

        public static Phrase Phrase(string Text, Font TextFont)
        {
            return new Phrase(Printable(Text), TextFont);
        }

        public static Paragraph Paragraph(string Text, Font TextFont)
        {
            return new Paragraph(Printable(Text), TextFont);
        }

        // In the size and style of iTextSharp's default font (12, normal)
        public static Paragraph Paragraph(string Text)
        {
            return Paragraph(Text, Get(12, Font.NORMAL));
        }

        // The third argument of HTMLWorker.ParseToList: every font the HTML asks for (font-family Times, Arial
        // or none) is Noto Serif in the size and style asked for
        public static Hashtable HtmlWorkerProps()
        {
            Hashtable props = new Hashtable();
            props["font_factory"] = htmlFontFactory;
            return props;
        }

        private class NotoFontFactory : FontFactoryImp
        {
            public override Font GetFont(string fontname, string encoding, bool embedded, float size, int style, Color color)
            {
                return PdfFonts.Get(size, style, color);
            }

            public override Font GetFont(string fontname, string encoding, bool embedded, float size, int style, Color color, bool cached)
            {
                return PdfFonts.Get(size, style, color);
            }
        }
        #endregion

        #region Tamil and Devanagari
        // True when one of the texts has a Tamil or Devanagari (Hindi) letter, also when written as an HTML
        // character reference (rich text). Blocks: Devanagari U+0900-097F, Vedic Extensions U+1CD0-1CFF,
        // Devanagari Extended U+A8E0-A8FF, Tamil U+0B80-0BFF, Tamil Supplement U+11FC0-11FFF.
        public static bool HasIndicText(params string[] Texts)
        {
            if (Texts == null)
                return false;

            foreach (string text in Texts)
            {
                if (string.IsNullOrEmpty(text))
                    continue;

                string decoded = text.IndexOf('&') >= 0 ? HttpUtility.HtmlDecode(text) : text;

                for (int i = 0; i < decoded.Length; i++)
                {
                    int code = decoded[i];

                    if (char.IsHighSurrogate(decoded[i]) && i + 1 < decoded.Length && char.IsLowSurrogate(decoded[i + 1]))
                    {
                        code = char.ConvertToUtf32(decoded[i], decoded[i + 1]);
                        i++;
                    }

                    if ((code >= 0x0900 && code <= 0x097F) || (code >= 0x1CD0 && code <= 0x1CFF) || (code >= 0xA8E0 && code <= 0xA8FF)
                        || (code >= 0x0B80 && code <= 0x0BFF) || (code >= 0x11FC0 && code <= 0x11FFF))
                        return true;
                }
            }

            return false;
        }

        // The columns of the table that the PDF prints; a column the table does not have is skipped
        public static bool HasIndicText(DataTable Table, params string[] Columns)
        {
            if (Table == null)
                return false;

            foreach (string column in Columns)
            {
                if (!Table.Columns.Contains(column))
                    continue;

                foreach (DataRow row in Table.Rows)
                {
                    if (HasIndicText(row[column].ToString()))
                        return true;
                }
            }

            return false;
        }

        // The organisation details of System Settings, printed in the PDF headers, letters and certificates
        public static bool OrganisationHasIndicText()
        {
            OrganisationDetails org = OrganisationDetails.Current;
            return HasIndicText(org.Name, org.ShortName, org.Term, org.SignOff, org.OfficeLabel, org.Line1, org.Line2,
                org.City, org.PinCode, org.Phone, org.Fax, org.Email);
        }

        // IndicTextMessage and what to use instead, for the page's message display
        public static string IndicTextMessageFor(string Instead)
        {
            return IndicTextMessage + "; " + Instead + ".";
        }
        #endregion
    }
}
