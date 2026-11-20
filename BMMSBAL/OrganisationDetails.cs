using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Web;
using BMMSDAL;

namespace BMMSBAL
{
    /// <summary>
    /// The organisation details printed on notices, minutes, reports and certificates
    /// (App_Setting, BMMS-Fix-OrganisationSettings-Step19.sql) and the organisation logo
    /// (~/Files/Branding/report-logo.png). This is the only place that formats them.
    ///
    /// An empty setting leaves its text out; nothing prints a placeholder. The ...Html members
    /// are HTML-encoded (mail bodies, HTML reports, HTML-to-PDF text); the others are plain text
    /// for iTextSharp paragraphs.
    /// </summary>
    public class OrganisationDetails
    {
        // The 12 settings, in the order of spr_GetOrganisationSettings and spr_SetOrganisationSettings
        public static readonly string[] SettingCodes = {
            "OrganisationName", "OrganisationShortName", "OrganisationTerm", "CertificateSignOff",
            "RegisteredOfficeLabel", "RegisteredOfficeLine1", "RegisteredOfficeLine2", "RegisteredOfficeCity",
            "RegisteredOfficePinCode", "OrganisationPhone", "OrganisationFax", "OrganisationEmail" };

        public const string DefaultTerm = "Company";

        public const string LogoVirtualPath = "~/Files/Branding/report-logo.png";
        public const string LogoReportSrc = "../Files/Branding/report-logo.png";   // HTML reports under ~/Report
        public const int LogoMaxBytes = 500 * 1024;
        public const int LogoMaxWidth = 1000;
        public const int LogoMaxHeight = 300;

        private const string RequestCacheKey = "BMMS.OrganisationDetails";

        public string Name = string.Empty;
        public string ShortName = string.Empty;
        public string Term = string.Empty;
        public string SignOff = string.Empty;
        public string OfficeLabel = string.Empty;
        public string Line1 = string.Empty;
        public string Line2 = string.Empty;
        public string City = string.Empty;
        public string PinCode = string.Empty;
        public string Phone = string.Empty;
        public string Fax = string.Empty;
        public string Email = string.Empty;

        #region Reading
        /// <summary>The settings of the current request, read from the database once per request.</summary>
        public static OrganisationDetails Current
        {
            get
            {
                HttpContext context = HttpContext.Current;
                if (context != null && context.Items[RequestCacheKey] is OrganisationDetails)
                    return (OrganisationDetails)context.Items[RequestCacheKey];

                OrganisationDetails details = FromTable(UtilitiesDB.GetOrganisationSettings());
                if (context != null)
                    context.Items[RequestCacheKey] = details;
                return details;
            }
        }

        /// <summary>Seq, SettingCode, SettingValue, LastChangedOn, LastChangedBy (System Settings page).</summary>
        public static DataTable GetSettings()
        {
            return UtilitiesDB.GetOrganisationSettings();
        }

        public static OrganisationDetails FromTable(DataTable dt)
        {
            OrganisationDetails d = new OrganisationDetails();
            foreach (DataRow row in dt.Rows)
            {
                string value = row["SettingValue"].ToString().Trim();
                switch (row["SettingCode"].ToString())
                {
                    case "OrganisationName": d.Name = value; break;
                    case "OrganisationShortName": d.ShortName = value; break;
                    case "OrganisationTerm": d.Term = value; break;
                    case "CertificateSignOff": d.SignOff = value; break;
                    case "RegisteredOfficeLabel": d.OfficeLabel = value; break;
                    case "RegisteredOfficeLine1": d.Line1 = value; break;
                    case "RegisteredOfficeLine2": d.Line2 = value; break;
                    case "RegisteredOfficeCity": d.City = value; break;
                    case "RegisteredOfficePinCode": d.PinCode = value; break;
                    case "OrganisationPhone": d.Phone = value; break;
                    case "OrganisationFax": d.Fax = value; break;
                    case "OrganisationEmail": d.Email = value; break;
                }
            }
            return d;
        }
        #endregion

        #region Saving
        /// <summary>Saves all 12 settings (Values in the order of SettingCodes), or none.</summary>
        public static MeetingChangeResult Save(string[] Values, int ActingUserId)
        {
            MeetingChangeResult result = MeetingChangeResult.FromTable(UtilitiesDB.SetOrganisationSettings(Values, ActingUserId));

            // The rest of this request prints the new values
            if (HttpContext.Current != null)
                HttpContext.Current.Items.Remove(RequestCacheKey);

            return result;
        }
        #endregion

        #region Text pieces (plain)
        public string NameUpper { get { return Upper(Name); } }
        public string OfficeLabelUpper { get { return Upper(OfficeLabel); } }
        public string CityUpper { get { return Upper(City); } }
        public string AddressUpper { get { return Upper(Address); } }

        /// <summary>LABEL, CITY: the line printed under the logo.</summary>
        public string OfficeLineUpper { get { return Upper(OfficeLine); } }

        /// <summary>Mail headers: the short name, or the legal name.</summary>
        public string MailName { get { return ShortName != string.Empty ? ShortName : Name; } }

        /// <summary>"Bank", "Company", ...: never empty, it stands inside a sentence.</summary>
        public string TermText { get { return Term != string.Empty ? Term : DefaultTerm; } }

        /// <summary>The text after "For": the sign-off, or the legal name.</summary>
        public string SignOffName { get { return SignOff != string.Empty ? SignOff : Name; } }

        /// <summary>Label, City: the line printed under the logo and in mail headers.</summary>
        public string OfficeLine { get { return Join(", ", OfficeLabel, City); } }

        /// <summary>City - PIN</summary>
        public string CityPin { get { return Join(" - ", City, PinCode); } }

        /// <summary>Line 1, Line 2, City - PIN</summary>
        public string Address { get { return Join(", ", Line1, Line2, CityPin); } }

        /// <summary>One-line report header: NAME, LABEL, CITY - PIN</summary>
        public string HeaderLine { get { return Upper(Join(", ", Name, OfficeLabel, CityPin)); } }

        /// <summary>Certificate heading: "Label: Address."</summary>
        public string CertificateOfficeLine { get { return EndWithStop(Join(": ", OfficeLabel, Address)); } }

        /// <summary>Certificate footer: "Label, Address."</summary>
        public string FooterOfficeLine { get { return EndWithStop(Join(", ", OfficeLabel, Address)); } }

        /// <summary>Phone: ..., Fax: ..., E-Mail: ... (the parts that are set)</summary>
        public string ContactLine
        {
            get
            {
                return Join(", ", Phone != string.Empty ? "Phone: " + Phone : string.Empty,
                                  Fax != string.Empty ? "Fax: " + Fax : string.Empty,
                                  Email != string.Empty ? "E-Mail: " + Email : string.Empty);
            }
        }
        #endregion

        #region Text pieces (HTML)
        public static string Html(string Text)
        {
            return HttpUtility.HtmlEncode(Text);
        }

        /// <summary>
        /// Notice / Followup / Action Taken mail: the bold centred header row (MAIL NAME, OFFICE LINE),
        /// or nothing when both are empty.
        /// </summary>
        public string MailHeaderRowHtml()
        {
            string lines = Join(" <br />", Html(Upper(MailName)), Html(Upper(OfficeLine)));
            if (lines == string.Empty)
                return string.Empty;

            return "<tr><td colspan='2' style='text-align:center; font-weight:bold;'>" + lines + "</td></tr>";
        }

        /// <summary>
        /// Sitting-fee certificate footer: "<b>Sign-off</b> Label, Address." and, on the next line,
        /// the contact line; the parts that are set.
        /// </summary>
        public string CertificateFooterHtml()
        {
            string office = Join(" ", SignOffName != string.Empty ? "<b>" + Html(SignOffName) + "</b>" : string.Empty,
                                      Html(FooterOfficeLine));
            return Join("<br />", office, Html(ContactLine));
        }
        #endregion

        #region Logo
        public static string LogoFilePath
        {
            get { return HttpContext.Current.Server.MapPath(LogoVirtualPath); }
        }

        public static bool HasLogo
        {
            get { return File.Exists(LogoFilePath); }
        }

        /// <summary>HTML reports: the centred logo, or nothing when no logo is set.</summary>
        public static string ReportBannerHtml()
        {
            if (!HasLogo)
                return string.Empty;
            return "<div style='float:left; width:100%; text-align:center;'><img src='" + LogoReportSrc + "' /></div>";
        }

        /// <summary>
        /// Checks an uploaded file and returns it re-drawn as PNG. Returns an error message, or
        /// string.Empty when Png and Detail are set. The file must decode completely as a PNG, JPEG
        /// or GIF image within the size limits; its name and type as sent are never used.
        /// </summary>
        public static string PrepareLogo(byte[] Data, out byte[] Png, out string Detail)
        {
            Png = null;
            Detail = string.Empty;

            if (Data == null || Data.Length == 0)
                return "Choose an image file first.";
            if (Data.Length > LogoMaxBytes)
                return "The logo is larger than 500 KB.";

            try
            {
                using (MemoryStream input = new MemoryStream(Data))
                using (Image image = Image.FromStream(input, false, true))
                {
                    string format;
                    if (image.RawFormat.Equals(ImageFormat.Png))
                        format = "PNG";
                    else if (image.RawFormat.Equals(ImageFormat.Jpeg))
                        format = "JPEG";
                    else if (image.RawFormat.Equals(ImageFormat.Gif))
                        format = "GIF";
                    else
                        return "The logo must be a PNG, JPEG or GIF image.";

                    // GDI+ draws a cut or damaged file without an error: check the file's own structure
                    if (!IsWellFormed(Data, format))
                        return "The file is not a valid image (it is damaged or incomplete).";

                    int width = image.Width;
                    int height = image.Height;
                    if (width < 1 || height < 1 || width > LogoMaxWidth || height > LogoMaxHeight)
                        return "The logo must be at most " + LogoMaxWidth + " x " + LogoMaxHeight + " pixels (this one is "
                             + width + " x " + height + ").";

                    // Drawing decodes every pixel: a damaged file fails here
                    using (Bitmap copy = new Bitmap(width, height, PixelFormat.Format32bppArgb))
                    {
                        using (Graphics g = Graphics.FromImage(copy))
                        {
                            g.Clear(Color.Transparent);
                            g.DrawImage(image, 0, 0, width, height);
                        }

                        using (MemoryStream output = new MemoryStream())
                        {
                            copy.Save(output, ImageFormat.Png);
                            Png = output.ToArray();
                        }
                    }

                    Detail = format + " " + width + " x " + height + ", " + ((Png.Length + 1023) / 1024) + " KB";
                }
            }
            catch (ArgumentException)
            {
                Png = null;
                return "The file is not a valid image.";
            }
            catch (System.Runtime.InteropServices.ExternalException)
            {
                Png = null;
                return "The file is not a valid image.";
            }
            catch (OutOfMemoryException)
            {
                Png = null;
                return "The file is not a valid image.";
            }

            return string.Empty;
        }

        /// <summary>Stores the logo (fixed name) after the database has recorded the upload. Returns a message.</summary>
        public static string UploadLogo(byte[] Data, int ActingUserId, out bool Saved)
        {
            Saved = false;

            byte[] png;
            string detail;
            string error = PrepareLogo(Data, out png, out detail);
            if (error != string.Empty)
                return error;

            MeetingChangeResult result = MeetingChangeResult.FromTable(UtilitiesDB.RecordOrganisationLogo("Upload", detail, ActingUserId));
            if (result.Result != 1)
                return LogoRefusalMessage(result);

            string path = LogoFilePath;
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            string temp = path + ".tmp";
            File.WriteAllBytes(temp, png);
            if (File.Exists(path))
                File.Replace(temp, path, null);
            else
                File.Move(temp, path);

            Saved = true;
            return "Logo saved (" + detail + ").";
        }

        /// <summary>Deletes the logo after the database has recorded the removal. Returns a message.</summary>
        public static string RemoveLogo(int ActingUserId, out bool Removed)
        {
            Removed = false;

            if (!HasLogo)
                return "No logo is set.";

            MeetingChangeResult result = MeetingChangeResult.FromTable(UtilitiesDB.RecordOrganisationLogo("Remove", string.Empty, ActingUserId));
            if (result.Result != 1)
                return LogoRefusalMessage(result);

            File.Delete(LogoFilePath);

            Removed = true;
            return "Logo removed.";
        }

        #region Image structure
        private static bool IsWellFormed(byte[] Data, string Format)
        {
            try
            {
                if (Format == "PNG")
                    return IsWellFormedPng(Data);
                if (Format == "JPEG")
                    return IsWellFormedJpeg(Data);
                if (Format == "GIF")
                    return IsWellFormedGif(Data);
                return false;
            }
            catch (IndexOutOfRangeException)
            {
                return false;   // a length that points past the end of the file
            }
        }

        // Signature, then chunks (length, type, data, CRC-32 of type and data): IHDR first, at
        // least one IDAT, IEND last and nothing after it, every CRC correct.
        private static bool IsWellFormedPng(byte[] d)
        {
            byte[] signature = { 137, 80, 78, 71, 13, 10, 26, 10 };
            if (d.Length < 8)
                return false;
            for (int i = 0; i < 8; i++)
                if (d[i] != signature[i])
                    return false;

            int pos = 8;
            bool first = true, idat = false;
            while (pos + 12 <= d.Length)
            {
                long length = ((long)d[pos] << 24) | ((long)d[pos + 1] << 16) | ((long)d[pos + 2] << 8) | d[pos + 3];
                if (length > d.Length - pos - 12)
                    return false;
                string type = System.Text.Encoding.ASCII.GetString(d, pos + 4, 4);
                int dataLength = (int)length;

                uint crc = Crc32(d, pos + 4, dataLength + 4);
                int c = pos + 8 + dataLength;
                uint stored = ((uint)d[c] << 24) | ((uint)d[c + 1] << 16) | ((uint)d[c + 2] << 8) | d[c + 3];
                if (crc != stored)
                    return false;

                if (first && type != "IHDR")
                    return false;
                first = false;
                if (type == "IDAT")
                    idat = true;

                pos = c + 4;
                if (type == "IEND")
                    return idat && pos == d.Length;
            }
            return false;   // no IEND: cut short
        }

        // SOI, marker segments with lengths that fit, a frame (SOF) before the scan (SOS), and the
        // file ends with EOI.
        private static bool IsWellFormedJpeg(byte[] d)
        {
            if (d.Length < 4 || d[0] != 0xFF || d[1] != 0xD8 || d[d.Length - 2] != 0xFF || d[d.Length - 1] != 0xD9)
                return false;

            int pos = 2;
            bool frame = false;
            while (pos + 4 <= d.Length)
            {
                if (d[pos] != 0xFF)
                    return false;
                byte marker = d[pos + 1];
                if (marker == 0xFF)
                {
                    pos++;          // fill byte
                    continue;
                }
                int length = (d[pos + 2] << 8) | d[pos + 3];
                if (length < 2 || pos + 2 + length > d.Length)
                    return false;
                if ((marker >= 0xC0 && marker <= 0xCF) && marker != 0xC4 && marker != 0xC8 && marker != 0xCC)
                    frame = true;
                if (marker == 0xDA)
                    return frame;   // start of scan: the compressed data runs to the EOI checked above
                pos += 2 + length;
            }
            return false;
        }

        // Header, screen descriptor, colour table, then extensions and images made of sub-blocks,
        // up to the trailer (0x3B) as the last byte.
        private static bool IsWellFormedGif(byte[] d)
        {
            if (d.Length < 14)
                return false;
            string header = System.Text.Encoding.ASCII.GetString(d, 0, 6);
            if (header != "GIF87a" && header != "GIF89a")
                return false;

            int pos = 13;
            if ((d[10] & 0x80) != 0)
                pos += 3 * (1 << ((d[10] & 0x07) + 1));

            bool image = false;
            while (pos < d.Length)
            {
                byte block = d[pos];
                if (block == 0x3B)
                    return image && pos == d.Length - 1;
                if (block == 0x21)
                {
                    pos += 2;
                    pos = SkipSubBlocks(d, pos);
                }
                else if (block == 0x2C)
                {
                    byte flags = d[pos + 9];
                    pos += 10;
                    if ((flags & 0x80) != 0)
                        pos += 3 * (1 << ((flags & 0x07) + 1));
                    pos += 1;   // LZW minimum code size
                    pos = SkipSubBlocks(d, pos);
                    image = true;
                }
                else
                    return false;
                if (pos < 0)
                    return false;
            }
            return false;   // no trailer: cut short
        }

        private static int SkipSubBlocks(byte[] d, int pos)
        {
            while (pos < d.Length)
            {
                int size = d[pos];
                pos += 1 + size;
                if (size == 0)
                    return pos;
            }
            return -1;
        }

        private static uint[] crcTable;

        private static uint Crc32(byte[] d, int offset, int count)
        {
            if (crcTable == null)
            {
                uint[] table = new uint[256];
                for (uint n = 0; n < 256; n++)
                {
                    uint c = n;
                    for (int k = 0; k < 8; k++)
                        c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
                    table[n] = c;
                }
                crcTable = table;
            }

            uint crc = 0xFFFFFFFF;
            for (int i = offset; i < offset + count; i++)
                crc = crcTable[(crc ^ d[i]) & 0xFF] ^ (crc >> 8);
            return crc ^ 0xFFFFFFFF;
        }
        #endregion

        private static string LogoRefusalMessage(MeetingChangeResult Result)
        {
            if (Result.Reason == MeetingChangeReason.ActingUserInvalid)
                return Result.RefusalMessage();
            if (Result.Reason == MeetingChangeReason.NotFound)
                return "Only an Admin can change system settings.";
            return "Record Not Saved";
        }
        #endregion

        #region Helpers
        private static string Upper(string Text)
        {
            return Text.ToUpper(CultureInfo.InvariantCulture);
        }

        /// <summary>Joins the parts that are not empty.</summary>
        private static string Join(string Separator, params string[] Parts)
        {
            List<string> present = new List<string>();
            foreach (string part in Parts)
            {
                if (!string.IsNullOrEmpty(part))
                    present.Add(part);
            }
            return string.Join(Separator, present.ToArray());
        }

        private static string EndWithStop(string Text)
        {
            if (Text == string.Empty || Text.EndsWith("."))
                return Text;
            return Text + ".";
        }
        #endregion
    }
}
