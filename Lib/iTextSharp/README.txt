iTextSharp (third-party library)
================================

Used for every PDF the site makes: BMMSBAL\PDFUtilities.cs, PdfFonts.cs,
HtmlToPdfBuilder.cs, PDF_Reports.cs and the report pages of BMMS (Report\*.aspx.cs).

Version      4.0.2.0
Copyright    Copyright (C) 1999-2007 by Bruno Lowagie and Paulo Soares
             (from the file properties of itextsharp.dll)
Licence      To be confirmed. iTextSharp 4.x was published under the MPL 1.1 / LGPL;
             no licence text came with this copy. The owner adds the licence text of
             this version to this folder when it is confirmed.

itextsharp.dll
  Size       3,260,416 bytes
  SHA-256    C4907BAC90B902819E9E49E65FF00C01FFFFDF19899C2C9086A9529CB0F1FE89

Moved here   Step AZ1, from BMMS\bin\itextsharp.dll (tracked since the recovered
             baseline, 990b26d). The identical copy in BMMSBAL\bin\Debug was removed.

Referenced from BMMSBAL.csproj and BMMS.csproj with the HintPath
..\Lib\iTextSharp\itextsharp.dll; the build copies it to BMMS\bin.
