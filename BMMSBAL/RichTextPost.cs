using System;
using System.Text;

namespace BMMSBAL
{
    public enum RichTextPostResult
    {
        Text,
        Empty,
        TooLong,
        Invalid
    }

    /// <summary>
    /// The value of a rich-text editor as it travels in its hidden field (step A2a): the HTML as Base64 of its
    /// UTF-8 bytes, so the post never holds &lt; or &amp;# and request validation stays on. An empty field is
    /// empty text. The decoded HTML is not trusted: the caller cleans it with HtmlCleaner.Clean.
    /// </summary>
    public static class RichTextPost
    {
        private static readonly Encoding Utf8 = new UTF8Encoding(false, false);
        private static readonly Encoding Utf8Strict = new UTF8Encoding(false, true);

        #region Encode
        public static string Encode(string html)
        {
            if (string.IsNullOrEmpty(html))
                return string.Empty;

            return Convert.ToBase64String(Utf8.GetBytes(html));
        }
        #endregion

        #region Decode
        // html is the decoded text for Text and TooLong (over maxChars characters: the text is still given back,
        // so the editor keeps what was typed while the save is refused), else empty. The request size limit
        // bounds the work. Never throws.
        public static RichTextPostResult Decode(string posted, int maxChars, out string html)
        {
            html = string.Empty;

            if (string.IsNullOrEmpty(posted))
                return RichTextPostResult.Empty;

            try
            {
                string text = Utf8Strict.GetString(Convert.FromBase64String(posted));

                if (text.Length == 0)
                    return RichTextPostResult.Empty;

                html = text;
                return text.Length > maxChars ? RichTextPostResult.TooLong : RichTextPostResult.Text;
            }
            catch (FormatException)
            {
                return RichTextPostResult.Invalid;
            }
            catch (ArgumentException)
            {
                // Bytes that are not UTF-8 (DecoderFallbackException)
                return RichTextPostResult.Invalid;
            }
        }
        #endregion
    }
}
