using System;
using System.Configuration;
using System.Globalization;

namespace BMMSBAL
{
    /// <summary>
    /// The size limits of the rich-text editors (step A2a), read from Web.config appSettings:
    /// RichTextMaxChars (one editor, default 200000) and RichTextMaxTotalChars (all editors of one page,
    /// default 600000). Counted in characters of the editor's HTML. A key that is missing, empty or not a
    /// positive whole number gives the default. Used by the editor control, the script (the control writes
    /// the values into the page) and the server check. See Database/README.md, step A2a, for the request
    /// settings that must be raised together with these values.
    /// </summary>
    public static class RichTextLimits
    {
        public const string MaxCharsKey = "RichTextMaxChars";
        public const string MaxTotalCharsKey = "RichTextMaxTotalChars";

        public const int DefaultMaxChars = 200000;
        public const int DefaultMaxTotalChars = 600000;

        public const string TooLongMessage = "The text is too long. Shorten it or attach the document as a file.";

        public static int MaxChars
        {
            get { return Parse(ReadSetting(MaxCharsKey), DefaultMaxChars); }
        }

        public static int MaxTotalChars
        {
            get { return Parse(ReadSetting(MaxTotalCharsKey), DefaultMaxTotalChars); }
        }

        #region Parse
        // A positive whole number (digits only, spaces around allowed); anything else gives defaultValue
        public static int Parse(string value, int defaultValue)
        {
            int number;

            if (value != null
                && int.TryParse(value.Trim(), NumberStyles.None, CultureInfo.InvariantCulture, out number)
                && number > 0)
                return number;

            return defaultValue;
        }
        #endregion

        #region ReadSetting
        private static string ReadSetting(string key)
        {
            try
            {
                return ConfigurationManager.AppSettings[key];
            }
            catch (ConfigurationErrorsException)
            {
                return null;
            }
        }
        #endregion
    }
}
