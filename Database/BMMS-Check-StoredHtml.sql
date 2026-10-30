/* ============================================================================
   BMMS - What the stored rich text contains (step A1, read-only)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   READ-ONLY: nothing in the database is changed. The script uses two
   temporary tables (#StoredText, #Pattern), which are dropped at the end.

   Runs only on a database whose name starts with "BMMS" (meant for
   BMMS_Test). It has no USE line: select the database in SSMS first, then
   run the whole file (F5).

   Columns checked (a column that does not exist is reported and skipped):
     Agenda       AgendaText, ProposedResolution, MgrComments,
                  ControllerComments, ShortText (plain text, for comparison)
     Minutes      Directions, ActualResolution
     Action_Item  Directions, ActionText

   Result sets
     1  Per column: rows, rows with text, rows with any "<", longest value,
        total characters.
     2  Per column and pattern: rows containing the pattern (not case
        sensitive). The "on...= inside a tag" line is a broad match and can
        also count ordinary text; onclick, onerror and onload are exact.
     3  Per column and tag name: the number of rows that use the tag, one
        sample row id, and whether the tag is in the planned allow-list
        (p, br, b, strong, i, em, u, ul, ol, li, table, thead, tbody, tr,
        th, td). Tags outside the allow-list come first.
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase NOT LIKE N'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". This check runs only on a database whose name starts with BMMS (BMMS_Test). Select it and run again.', 16, 1, @CurrentDatabase);
    RETURN;
END

IF OBJECT_ID('tempdb..#StoredText') IS NOT NULL DROP TABLE #StoredText;
IF OBJECT_ID('tempdb..#Pattern') IS NOT NULL DROP TABLE #Pattern;

CREATE TABLE #StoredText
(
    TableName  SYSNAME       NOT NULL,
    ColumnName SYSNAME       NOT NULL,
    RowKey     INT           NULL,
    Txt        NVARCHAR(MAX) NULL
);

-- The columns to read: table, column, key column
DECLARE @Columns TABLE (Seq INT IDENTITY(1,1), TableName SYSNAME, ColumnName SYSNAME, KeyName SYSNAME);
INSERT INTO @Columns (TableName, ColumnName, KeyName) VALUES
    ('Agenda', 'AgendaText', 'AgendaId'),
    ('Agenda', 'ProposedResolution', 'AgendaId'),
    ('Agenda', 'MgrComments', 'AgendaId'),
    ('Agenda', 'ControllerComments', 'AgendaId'),
    ('Agenda', 'ShortText', 'AgendaId'),
    ('Minutes', 'Directions', 'MinutesId'),
    ('Minutes', 'ActualResolution', 'MinutesId'),
    ('Action_Item', 'Directions', 'ActionItemId'),
    ('Action_Item', 'ActionText', 'ActionItemId');

DECLARE @Seq INT = 1, @LastSeq INT, @TableName SYSNAME, @ColumnName SYSNAME, @KeyName SYSNAME;
DECLARE @KeyExpr NVARCHAR(300), @Sql NVARCHAR(MAX), @Line NVARCHAR(400);
SELECT @LastSeq = MAX(Seq) FROM @Columns;

WHILE (@Seq <= @LastSeq)
BEGIN
    SELECT @TableName = TableName, @ColumnName = ColumnName, @KeyName = KeyName FROM @Columns WHERE Seq = @Seq;

    IF (COL_LENGTH(N'dbo.' + QUOTENAME(@TableName), @ColumnName) IS NULL)
    BEGIN
        SET @Line = N'Not found, skipped: ' + @TableName + N'.' + @ColumnName;
        PRINT @Line;
    END
    ELSE
    BEGIN
        IF (COL_LENGTH(N'dbo.' + QUOTENAME(@TableName), @KeyName) IS NULL)
            SET @KeyExpr = N'CAST(NULL AS INT)';
        ELSE
            SET @KeyExpr = QUOTENAME(@KeyName);

        SET @Sql = N'INSERT INTO #StoredText (TableName, ColumnName, RowKey, Txt) '
                 + N'SELECT @T, @C, ' + @KeyExpr + N', CAST(' + QUOTENAME(@ColumnName) + N' AS NVARCHAR(MAX)) '
                 + N'FROM dbo.' + QUOTENAME(@TableName) + N';';
        EXEC sp_executesql @Sql, N'@T SYSNAME, @C SYSNAME', @T = @TableName, @C = @ColumnName;
    END

    SET @Seq = @Seq + 1;
END

/* ---- 1. Per column -------------------------------------------------------- */
SELECT TableName, ColumnName,
       COUNT(*) AS TotalRows,
       SUM(CASE WHEN LEN(ISNULL(Txt, N'')) > 0 THEN 1 ELSE 0 END) AS RowsWithText,
       SUM(CASE WHEN CHARINDEX(N'<', ISNULL(Txt, N'')) > 0 THEN 1 ELSE 0 END) AS RowsWithMarkup,
       MAX(LEN(ISNULL(Txt, N''))) AS LongestValue,
       SUM(CAST(LEN(ISNULL(Txt, N'')) AS BIGINT)) AS TotalCharacters
FROM #StoredText
GROUP BY TableName, ColumnName
ORDER BY TableName, ColumnName;

/* ---- 2. Per column and pattern -------------------------------------------- */
CREATE TABLE #Pattern (Seq INT IDENTITY(1,1), Label NVARCHAR(60) NOT NULL, LikePattern NVARCHAR(100) NOT NULL);
INSERT INTO #Pattern (Label, LikePattern) VALUES
    (N'<script',                  N'%<script%'),
    (N'<iframe',                  N'%<iframe%'),
    (N'<object',                  N'%<object%'),
    (N'<embed',                   N'%<embed%'),
    (N'javascript:',              N'%javascript:%'),
    (N'vbscript:',                N'%vbscript:%'),
    (N'data:',                    N'%data:%'),
    (N'onclick',                  N'%onclick%'),
    (N'onerror',                  N'%onerror%'),
    (N'onload',                   N'%onload%'),
    (N'on...= inside a tag (broad)', N'%<[a-z]%[ /]on[a-z]%=%'),
    (N'style=',                   N'%style=%'),
    (N'class=',                   N'%class=%'),
    (N'align=',                   N'%align=%'),
    (N'text-align',               N'%text-align%'),
    (N'<font',                    N'%<font%'),
    (N'<span',                    N'%<span%'),
    (N'<div',                     N'%<div%'),
    (N'<a (link)',                N'%<a %'),
    (N'<img',                     N'%<img%'),
    (N'<table',                   N'%<table%'),
    (N'<blockquote',              N'%<blockquote%'),
    (N'mso',                      N'%mso%'),
    (N'<o:p',                     N'%<o:p%'),
    (N'<!-- (comment)',           N'%<!--%'),
    (N'<style',                   N'%<style%'),
    (N'<xml',                     N'%<xml%'),
    (N'&nbsp;',                   N'%&nbsp;%'),
    (N'&#... (numeric reference)', N'%&#[0-9x]%');

SELECT s.TableName, s.ColumnName, p.Label AS Pattern,
       SUM(CASE WHEN s.Txt LIKE p.LikePattern THEN 1 ELSE 0 END) AS RowsContaining
FROM #StoredText s
CROSS JOIN #Pattern p
GROUP BY s.TableName, s.ColumnName, p.Seq, p.Label
ORDER BY s.TableName, s.ColumnName, p.Seq;

/* ---- 3. Per column and tag name ------------------------------------------- */
;WITH TagStart AS
(
    -- Every "<" in every value, found one after the other
    SELECT s.TableName, s.ColumnName, s.RowKey, s.Txt, CHARINDEX(N'<', s.Txt) AS Pos
    FROM #StoredText s
    WHERE CHARINDEX(N'<', ISNULL(s.Txt, N'')) > 0
    UNION ALL
    SELECT t.TableName, t.ColumnName, t.RowKey, t.Txt, CHARINDEX(N'<', t.Txt, t.Pos + 1)
    FROM TagStart t
    WHERE CHARINDEX(N'<', t.Txt, t.Pos + 1) > 0
),
TagPiece AS
(
    -- The 40 characters after "<" (after "</" for an end tag), when they start with a letter
    SELECT TableName, ColumnName, RowKey,
           SUBSTRING(Txt, Pos + CASE WHEN SUBSTRING(Txt, Pos + 1, 1) = N'/' THEN 2 ELSE 1 END, 40) AS Piece
    FROM TagStart
),
TagName AS
(
    SELECT TableName, ColumnName, RowKey,
           LOWER(LEFT(Piece, PATINDEX(N'%[^a-zA-Z0-9:_-]%', Piece + N' ') - 1)) AS Tag
    FROM TagPiece
    WHERE Piece LIKE N'[a-zA-Z]%'
)
SELECT TableName, ColumnName, Tag,
       CASE WHEN Tag IN (N'p', N'br', N'b', N'strong', N'i', N'em', N'u', N'ul', N'ol', N'li',
                         N'table', N'thead', N'tbody', N'tr', N'th', N'td') THEN N'yes' ELSE N'NO' END AS InAllowList,
       COUNT(DISTINCT RowKey) AS RowsUsingTag,
       MIN(RowKey) AS SampleRowId
FROM TagName
GROUP BY TableName, ColumnName, Tag
ORDER BY CASE WHEN Tag IN (N'p', N'br', N'b', N'strong', N'i', N'em', N'u', N'ul', N'ol', N'li',
                           N'table', N'thead', N'tbody', N'tr', N'th', N'td') THEN 1 ELSE 0 END,
         TableName, ColumnName, RowsUsingTag DESC, Tag
OPTION (MAXRECURSION 0);

DROP TABLE #Pattern;
DROP TABLE #StoredText;
