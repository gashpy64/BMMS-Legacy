using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;

namespace BMMSBAL
{
    /// <summary>
    /// Names of uploaded files made safe when the file is saved (step N1), so that every link to the file opens.
    /// Kept: letters of any script with their combining marks (Tamil and Hindi vowel signs and virama), decimal
    /// digits, the zero-width joiner and non-joiner, space, dot, hyphen, underscore and round brackets. Any other
    /// white space becomes one space; every other character (&amp; % + # , ; quotes, emoji ...) becomes _ (a run
    /// of them one _). Only the name is kept (no folder), in composed form (NFC); repeated dots become one; spaces
    /// and dots are trimmed at both ends; at most MaxLength characters with the extension kept, never cut between
    /// a letter and its marks. An empty name, or one of only _, becomes "file"; a Windows reserved name (CON, PRN,
    /// AUX, NUL, COM1 to COM9, LPT1 to LPT9, also with an extension) gets _ in front.
    /// Cleaning the result again gives the same name. Clean never throws and never returns an empty name.
    /// </summary>
    public static class SafeFileName
    {
        public const int MaxLength = 100;
        public const string Fallback = "file";

        // Dot plus 1 to 10 characters
        private const int MaxExtensionLength = 11;

        private const int MaxNumber = 999;

        private static readonly HashSet<string> Reserved = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "CON", "PRN", "AUX", "NUL",
            "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
            "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
        };

        #region Clean
        public static string Clean(string fileName)
        {
            try
            {
                string name = CleanCharacters(NameOnly(fileName));

                name = name.Normalize(NormalizationForm.FormC);
                name = CollapseDots(name);
                name = name.TrimEnd(' ', '.').TrimStart(' ');

                string stem;
                string ext;
                SplitExtension(name, out stem, out ext);

                stem = stem.Trim(' ', '.');

                if (IsEmptyName(stem))
                    stem = Fallback;

                // The part before the first dot decides; Windows ignores spaces at its end
                int firstDot = stem.IndexOf('.');
                bool reserved = Reserved.Contains((firstDot < 0 ? stem : stem.Substring(0, firstDot)).TrimEnd(' '));

                stem = Shorten(stem, MaxLength - ext.Length - (reserved ? 1 : 0));

                if (IsEmptyName(stem))
                    stem = Fallback;

                if (reserved)
                    stem = "_" + stem;

                return stem + ext;
            }
            catch (Exception)
            {
                // Not expected; the page must still get a usable name
                return Fallback;
            }
        }
        #endregion

        #region MakeUnique
        // fileName itself when no file of that name is in folder, else "stem (2).ext", "stem (3).ext" ... up to 999,
        // then a time stamp. Never longer than fileName or MaxLength, whichever is more. fileName is expected to be
        // cleaned already. Returns fileName unchanged when folder or fileName is empty or on any error.
        public static string MakeUnique(string folder, string fileName)
        {
            if (string.IsNullOrEmpty(folder) || string.IsNullOrEmpty(fileName))
                return fileName;

            try
            {
                if (!File.Exists(Path.Combine(folder, fileName)))
                    return fileName;

                string stem;
                string ext;
                SplitExtension(fileName, out stem, out ext);

                int limit = Math.Max(fileName.Length, MaxLength);

                for (int n = 2; n <= MaxNumber + 1; n++)
                {
                    string suffix = n <= MaxNumber
                        ? " (" + n.ToString(CultureInfo.InvariantCulture) + ")"
                        : " " + DateTime.Now.ToString("yyyyMMddHHmmssfff", CultureInfo.InvariantCulture);

                    string candidate = Shorten(stem, limit - ext.Length - suffix.Length) + suffix + ext;

                    if (!File.Exists(Path.Combine(folder, candidate)))
                        return candidate;
                }

                return fileName;
            }
            catch (Exception)
            {
                return fileName;
            }
        }
        #endregion

        #region NameOnly
        // The part after the last / or \ (Path.GetFileName is not used: it throws on some characters)
        private static string NameOnly(string fileName)
        {
            if (fileName == null)
                return string.Empty;

            int slash = fileName.LastIndexOfAny(new char[] { '/', '\\' });

            return slash < 0 ? fileName : fileName.Substring(slash + 1);
        }
        #endregion

        #region CleanCharacters
        private static string CleanCharacters(string name)
        {
            StringBuilder sb = new StringBuilder(name.Length);
            bool lastReplaced = false;

            foreach (char c in name)
            {
                if (char.IsWhiteSpace(c))
                {
                    if (sb.Length == 0 || sb[sb.Length - 1] != ' ')
                        sb.Append(' ');
                    lastReplaced = false;
                }
                else if (IsKept(c))
                {
                    sb.Append(c);
                    lastReplaced = false;
                }
                else
                {
                    if (!lastReplaced)
                        sb.Append('_');
                    lastReplaced = true;
                }
            }

            return sb.ToString();
        }
        #endregion

        #region IsKept
        // Surrogates (emoji, rare letters outside the first plane) are not kept: a lone one cannot be normalised
        private static bool IsKept(char c)
        {
            if (char.IsSurrogate(c))
                return false;

            if (char.IsLetter(c) || IsMark(c) || char.IsDigit(c))
                return true;

            return c == '.' || c == '-' || c == '_' || c == '(' || c == ')' || IsJoiner(c);
        }
        #endregion

        #region IsMark
        private static bool IsMark(char c)
        {
            UnicodeCategory category = char.GetUnicodeCategory(c);

            return category == UnicodeCategory.NonSpacingMark || category == UnicodeCategory.SpacingCombiningMark;
        }
        #endregion

        #region IsJoiner
        // Zero-width non-joiner and joiner, used inside some Hindi spellings
        private static bool IsJoiner(char c)
        {
            return c == '‌' || c == '‍';
        }
        #endregion

        #region CollapseDots
        private static string CollapseDots(string name)
        {
            StringBuilder sb = new StringBuilder(name.Length);

            foreach (char c in name)
            {
                if (c == '.' && sb.Length > 0 && sb[sb.Length - 1] == '.')
                    continue;
                sb.Append(c);
            }

            return sb.ToString();
        }
        #endregion

        #region SplitExtension
        // The extension is the last dot with 1 to 10 characters after it and no space in them
        private static void SplitExtension(string name, out string stem, out string ext)
        {
            int dot = name.LastIndexOf('.');
            int length = name.Length - dot;

            if (dot >= 0 && length >= 2 && length <= MaxExtensionLength && name.IndexOf(' ', dot) < 0)
            {
                stem = name.Substring(0, dot);
                ext = name.Substring(dot);
            }
            else
            {
                stem = name;
                ext = string.Empty;
            }
        }
        #endregion

        #region Shorten
        // At most max characters, cut where the first character left out is not a mark (a letter keeps its marks)
        // and not after a joiner, then spaces and dots trimmed at the end
        private static string Shorten(string stem, int max)
        {
            if (max < 0)
                max = 0;

            if (stem.Length <= max)
                return stem;

            int cut = max;
            while (cut > 0 && (IsMark(stem[cut]) || IsJoiner(stem[cut - 1])))
                cut--;

            return stem.Substring(0, cut).TrimEnd(' ', '.');
        }
        #endregion

        #region IsEmptyName
        private static bool IsEmptyName(string stem)
        {
            return stem.Trim('_').Length == 0;
        }
        #endregion
    }
}
