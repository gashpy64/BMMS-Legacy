/* ============================================================================
   BMMS - Complete the State_Master list (step S1)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   dbo.State_Master (State_Id, State_Code, State_Name) held three rows:
   1 TN Tamil Nadu, 2 AP "Andhra Pradash", 3 KE Kerala. The Member page State
   dropdown reads it through spr_GetStateMaster; no page maintains the table.

   Decision (Consultant, 2026-10-31):
     - State_Id 1, 2 and 3 are kept.
     - Id 2 is named "Andhra Pradesh"; the code of id 3 becomes KL.
     - The remaining 25 states and the 8 union territories are added.
     - The dropdown lists the states by name.

   What the script does, in one transaction (SET XACT_ABORT ON, TRY/CATCH:
   any error rolls everything back and says so):
     1. Fixes the name of id 2 and the code of id 3 (only when not yet done).
     2. Inserts each of the 33 new rows only when neither its code nor its
        name is in the table yet (compared ignoring case and spaces). A row
        whose code or name is already there is skipped and listed, never
        changed. New ids are MAX(State_Id) + 1, + 2 ... in the order of the
        list below, so a table holding only ids 1 to 3 gets ids 4 to 36. When
        State_Id is an identity column, the rows are inserted with
        IDENTITY_INSERT, and the identity continues after the highest id.
     3. spr_GetStateMaster: left alone when it already sorts by State_Name;
        otherwise replaced by the same columns (as SQL Server describes its
        result today) from dbo.State_Master ORDER BY State_Name. Its old text
        is shown in the results and printed before anything is changed: keep
        it for the rollback (Database/README.md, step S1). Marker
        StateMaster-S1.
   Nothing is deleted. Safe to run twice: a second run changes nothing and
   reports 0 fixed and 0 inserted.

   Checks first, and stops with nothing changed when one fails:
     - the current database name starts with "BMMS";
     - State_Master has State_Id, State_Code (at least 2 characters) and
       State_Name (at least 40 characters, the longest new name), and no
       other column that needs a value;
     - id 2 is "Andhra Pradash" or "Andhra Pradesh"; id 3 is "Kerala" with
       code KE or KL; no other row has code KL;
     - no code and no name is in the table twice;
     - spr_GetStateMaster exists; when it must be replaced, it has no
       parameter, no WHERE and no JOIN, and every column it returns comes
       from State_Master.

   It has no USE line: select the database in SSMS first (BMMS_Test, then
   BMMS). Take a backup first. Run order and browser checks: Database/README.md,
   step S1.
   ============================================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase NOT LIKE N'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". This script runs only on a BMMS database. Select it and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    RETURN;
END
PRINT N'Database: ' + @CurrentDatabase;

-- The 33 new rows, in the order of the decision (states, then union territories)
DECLARE @New TABLE (Seq INT IDENTITY(1,1), State_Code VARCHAR(10), State_Name VARCHAR(100));
INSERT INTO @New (State_Code, State_Name) VALUES
    ('AR', 'Arunachal Pradesh'), ('AS', 'Assam'), ('BR', 'Bihar'), ('CG', 'Chhattisgarh'), ('GA', 'Goa'),
    ('GJ', 'Gujarat'), ('HR', 'Haryana'), ('HP', 'Himachal Pradesh'), ('JH', 'Jharkhand'), ('KA', 'Karnataka'),
    ('MP', 'Madhya Pradesh'), ('MH', 'Maharashtra'), ('MN', 'Manipur'), ('ML', 'Meghalaya'), ('MZ', 'Mizoram'),
    ('NL', 'Nagaland'), ('OD', 'Odisha'), ('PB', 'Punjab'), ('RJ', 'Rajasthan'), ('SK', 'Sikkim'),
    ('TG', 'Telangana'), ('TR', 'Tripura'), ('UP', 'Uttar Pradesh'), ('UK', 'Uttarakhand'), ('WB', 'West Bengal'),
    ('AN', 'Andaman and Nicobar Islands'), ('CH', 'Chandigarh'), ('DD', 'Dadra and Nagar Haveli and Daman and Diu'),
    ('DL', 'Delhi'), ('JK', 'Jammu and Kashmir'), ('LA', 'Ladakh'), ('LD', 'Lakshadweep'), ('PY', 'Puducherry');

---------------------------------------------------------------------------
-- 1. Checks (nothing is changed before all of them pass)
---------------------------------------------------------------------------
DECLARE @CodeChars INT, @NameChars INT, @CodeType SYSNAME, @NameType SYSNAME, @IdFound INT, @OtherRequired SYSNAME;
DECLARE @NeedName INT, @NeedCode INT;

SELECT @NeedName = MAX(LEN(State_Name)), @NeedCode = MAX(LEN(State_Code)) FROM @New;

SELECT @IdFound = COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = N'dbo' AND TABLE_NAME = N'State_Master' AND COLUMN_NAME = N'State_Id';
SELECT @CodeChars = CHARACTER_MAXIMUM_LENGTH, @CodeType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = N'dbo' AND TABLE_NAME = N'State_Master' AND COLUMN_NAME = N'State_Code';
SELECT @NameChars = CHARACTER_MAXIMUM_LENGTH, @NameType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = N'dbo' AND TABLE_NAME = N'State_Master' AND COLUMN_NAME = N'State_Name';

IF (@IdFound = 0 OR @CodeType IS NULL OR @NameType IS NULL)
BEGIN
    RAISERROR('dbo.State_Master or one of its columns State_Id, State_Code, State_Name was not found. Nothing was changed.', 16, 1);
    RETURN;
END
IF (@CodeChars IS NULL OR (@CodeChars <> -1 AND @CodeChars < @NeedCode)
    OR @NameChars IS NULL OR (@NameChars <> -1 AND @NameChars < @NeedName))
BEGIN
    RAISERROR('State_Code must hold %d and State_Name %d characters (found %s(%d) and %s(%d)). Widening a column is not part of this script. Nothing was changed.', 16, 1,
              @NeedCode, @NeedName, @CodeType, @CodeChars, @NameType, @NameChars);
    RETURN;
END

-- Any other column must take NULL, have a default or be computed, since the script writes only the three
SELECT TOP 1 @OtherRequired = c.name
FROM sys.columns c
WHERE c.object_id = OBJECT_ID('dbo.State_Master')
  AND c.name NOT IN ('State_Id', 'State_Code', 'State_Name')
  AND c.is_nullable = 0 AND c.default_object_id = 0 AND c.is_computed = 0 AND c.is_identity = 0;
IF (@OtherRequired IS NOT NULL)
BEGIN
    RAISERROR('State_Master has another column that needs a value (%s). This script writes only State_Id, State_Code and State_Name. Nothing was changed.', 16, 1, @OtherRequired);
    RETURN;
END

DECLARE @Name2 VARCHAR(200), @Code3 VARCHAR(50), @Name3 VARCHAR(200), @OtherKL INT;
SELECT @Name2 = LTRIM(RTRIM(State_Name)) FROM dbo.State_Master WHERE State_Id = 2;
SELECT @Code3 = UPPER(LTRIM(RTRIM(State_Code))), @Name3 = LTRIM(RTRIM(State_Name)) FROM dbo.State_Master WHERE State_Id = 3;
SELECT @OtherKL = COUNT(*) FROM dbo.State_Master WHERE UPPER(LTRIM(RTRIM(State_Code))) = 'KL' AND State_Id <> 3;

IF (@Name2 IS NULL OR @Name2 NOT IN ('Andhra Pradash', 'Andhra Pradesh'))
BEGIN
    SET @Name2 = ISNULL(@Name2, '(no row)');
    RAISERROR('State_Id 2 is "%s", not "Andhra Pradash" or "Andhra Pradesh". Check the table. Nothing was changed.', 16, 1, @Name2);
    RETURN;
END
IF (@Code3 IS NULL OR @Name3 <> 'Kerala' OR @Code3 NOT IN ('KE', 'KL'))
BEGIN
    SET @Code3 = ISNULL(@Code3, '(no row)');
    SET @Name3 = ISNULL(@Name3, '(no row)');
    RAISERROR('State_Id 3 is "%s" "%s", not Kerala with code KE or KL. Check the table. Nothing was changed.', 16, 1, @Code3, @Name3);
    RETURN;
END
IF (@OtherKL > 0)
BEGIN
    RAISERROR('Another row than State_Id 3 already has the code KL. Check the table. Nothing was changed.', 16, 1);
    RETURN;
END

DECLARE @DupCodes INT, @DupNames INT;
SELECT @DupCodes = COUNT(*) FROM (SELECT UPPER(REPLACE(LTRIM(RTRIM(State_Code)), ' ', '')) AS K FROM dbo.State_Master GROUP BY UPPER(REPLACE(LTRIM(RTRIM(State_Code)), ' ', '')) HAVING COUNT(*) > 1) d;
SELECT @DupNames = COUNT(*) FROM (SELECT UPPER(REPLACE(LTRIM(RTRIM(State_Name)), ' ', '')) AS K FROM dbo.State_Master GROUP BY UPPER(REPLACE(LTRIM(RTRIM(State_Name)), ' ', '')) HAVING COUNT(*) > 1) d;
IF (@DupCodes > 0 OR @DupNames > 0)
BEGIN
    RAISERROR('State_Master already has %d code(s) and %d name(s) more than once. Clean them up first. Nothing was changed.', 16, 1, @DupCodes, @DupNames);
    RETURN;
END

-- spr_GetStateMaster: does it already sort by State_Name; if not, can it be rebuilt with the same columns?
DECLARE @OldProc NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetStateMaster'));
IF (@OldProc IS NULL)
BEGIN
    RAISERROR('spr_GetStateMaster was not found. Nothing was changed.', 16, 1);
    RETURN;
END

DECLARE @Flat NVARCHAR(MAX) = UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@OldProc, CHAR(9), ''), CHAR(10), ''), CHAR(13), ''), ' ', ''), '[', ''), ']', ''));
DECLARE @AlreadySorted BIT = CASE WHEN @Flat LIKE N'%ORDERBYSTATE_NAME%'
                                    OR @Flat LIKE N'%ORDERBYSTATE_MASTER.STATE_NAME%'
                                    OR @Flat LIKE N'%ORDERBYDBO.STATE_MASTER.STATE_NAME%' THEN 1 ELSE 0 END;
DECLARE @NewProc NVARCHAR(MAX), @SelectList NVARCHAR(MAX), @ProcProblem NVARCHAR(400);

IF (@AlreadySorted = 0)
BEGIN
    DECLARE @Described TABLE (column_ordinal INT, name SYSNAME NULL, source_table SYSNAME NULL, source_column SYSNAME NULL, is_hidden BIT, error_message NVARCHAR(4000) NULL);
    INSERT INTO @Described (column_ordinal, name, source_table, source_column, is_hidden, error_message)
    SELECT column_ordinal, name, source_table, source_column, is_hidden, error_message
    FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetStateMaster'), 1);

    DECLARE @DescribeError NVARCHAR(4000), @Columns INT, @ForeignColumns INT, @HasParameters INT;
    SELECT TOP 1 @DescribeError = error_message FROM @Described WHERE error_message IS NOT NULL;
    SELECT @Columns = COUNT(*) FROM @Described WHERE is_hidden = 0 AND error_message IS NULL;
    SELECT @ForeignColumns = COUNT(*) FROM @Described
    WHERE is_hidden = 0 AND error_message IS NULL
      AND (source_table IS NULL OR source_table <> N'State_Master' OR source_column IS NULL);
    SELECT @HasParameters = COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_GetStateMaster');

    IF (@DescribeError IS NOT NULL)
        SET @ProcProblem = N'its result could not be described: ' + LEFT(@DescribeError, 300);
    ELSE IF (@Columns = 0)
        SET @ProcProblem = N'it returns no columns';
    ELSE IF (@ForeignColumns > 0)
        SET @ProcProblem = N'it returns a column that does not come from State_Master';
    ELSE IF (@HasParameters > 0)
        SET @ProcProblem = N'it has parameters';
    ELSE IF (@Flat LIKE N'%WHERE%' OR @Flat LIKE N'%JOIN%')
        SET @ProcProblem = N'it has a WHERE or a JOIN';

    IF (@ProcProblem IS NOT NULL)
    BEGIN
        SELECT @OldProc AS spr_GetStateMaster_CurrentText;
        RAISERROR('spr_GetStateMaster does not sort by State_Name and is not replaced automatically: %s. Its text is in the results; send it to the Consultant. Nothing was changed.', 16, 1, @ProcProblem);
        RETURN;
    END

    -- The same columns, in the same order and under the same names, as today
    SELECT @SelectList = STUFF((
        SELECT N', ' + QUOTENAME(source_column)
             + CASE WHEN name <> source_column THEN N' AS ' + QUOTENAME(name) ELSE N'' END
        FROM @Described
        WHERE is_hidden = 0
        ORDER BY column_ordinal
        FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N'');

    SET @NewProc = N'CREATE OR ALTER PROCEDURE [dbo].[spr_GetStateMaster]
AS
-- StateMaster-S1: the states in name order, for the State dropdown of the Member page
BEGIN
	SET NOCOUNT ON;

	SELECT ' + @SelectList + N'
	FROM dbo.State_Master
	ORDER BY State_Name;
END';

    SELECT @OldProc AS spr_GetStateMaster_OldText_KeepForRollback;
    PRINT N'spr_GetStateMaster, old text (keep it for the rollback):';
    PRINT @OldProc;
END

---------------------------------------------------------------------------
-- 2. The changes, in one transaction
---------------------------------------------------------------------------
DECLARE @IsIdentity INT = COLUMNPROPERTY(OBJECT_ID('dbo.State_Master'), 'State_Id', 'IsIdentity');
DECLARE @MaxId INT;
DECLARE @Fixed2 INT = 0, @Fixed3 INT = 0, @Inserted INT = 0, @ProcReplaced INT = 0, @IdentityOn BIT = 0;

-- Rows to insert, and rows skipped with the reason
DECLARE @Plan TABLE (Seq INT, State_Code VARCHAR(10), State_Name VARCHAR(100), NewId INT NULL, SkipReason VARCHAR(300) NULL);

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE dbo.State_Master SET State_Name = 'Andhra Pradesh' WHERE State_Id = 2 AND State_Name <> 'Andhra Pradesh';
    SET @Fixed2 = @@ROWCOUNT;

    UPDATE dbo.State_Master SET State_Code = 'KL' WHERE State_Id = 3 AND UPPER(LTRIM(RTRIM(State_Code))) = 'KE';
    SET @Fixed3 = @@ROWCOUNT;

    INSERT INTO @Plan (Seq, State_Code, State_Name, SkipReason)
    SELECT n.Seq, n.State_Code, n.State_Name,
           CASE WHEN c.State_Id IS NOT NULL
                    THEN 'code already there (State_Id ' + CAST(c.State_Id AS VARCHAR(12)) + ', ' + c.State_Name + ')'
                WHEN m.State_Id IS NOT NULL
                    THEN 'name already there (State_Id ' + CAST(m.State_Id AS VARCHAR(12)) + ', code ' + m.State_Code + ')'
           END
    FROM @New n
    OUTER APPLY (SELECT TOP 1 s.State_Id, s.State_Name FROM dbo.State_Master s
                 WHERE UPPER(REPLACE(LTRIM(RTRIM(s.State_Code)), ' ', '')) = UPPER(REPLACE(n.State_Code, ' ', '')) ORDER BY s.State_Id) c
    OUTER APPLY (SELECT TOP 1 s.State_Id, s.State_Code FROM dbo.State_Master s
                 WHERE UPPER(REPLACE(LTRIM(RTRIM(s.State_Name)), ' ', '')) = UPPER(REPLACE(n.State_Name, ' ', '')) ORDER BY s.State_Id) m;

    SELECT @MaxId = ISNULL(MAX(State_Id), 0) FROM dbo.State_Master WITH (UPDLOCK, HOLDLOCK);

    UPDATE p SET NewId = @MaxId + r.Rn
    FROM @Plan p
    JOIN (SELECT Seq, ROW_NUMBER() OVER (ORDER BY Seq) AS Rn FROM @Plan WHERE SkipReason IS NULL) r ON r.Seq = p.Seq;

    IF (@IsIdentity = 1)
    BEGIN
        SET IDENTITY_INSERT dbo.State_Master ON;
        SET @IdentityOn = 1;
    END

    INSERT INTO dbo.State_Master (State_Id, State_Code, State_Name)
    SELECT NewId, State_Code, State_Name FROM @Plan WHERE NewId IS NOT NULL ORDER BY NewId;
    SET @Inserted = @@ROWCOUNT;

    IF (@IdentityOn = 1)
    BEGIN
        SET IDENTITY_INSERT dbo.State_Master OFF;
        SET @IdentityOn = 0;
    END

    IF (@AlreadySorted = 0)
    BEGIN
        EXEC sys.sp_executesql @NewProc;
        SET @ProcReplaced = 1;
    END

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0)
        ROLLBACK TRANSACTION;
    IF (@IdentityOn = 1)
        SET IDENTITY_INSERT dbo.State_Master OFF;
    DECLARE @ErrorText NVARCHAR(2048) = ERROR_MESSAGE();
    DECLARE @ErrorNumber INT = ERROR_NUMBER();
    RAISERROR('The script failed and was rolled back completely, nothing was changed (error %d): %s', 16, 1, @ErrorNumber, @ErrorText);
    RETURN;
END CATCH

---------------------------------------------------------------------------
-- 3. Report
---------------------------------------------------------------------------
DECLARE @Line NVARCHAR(400), @Skipped INT, @i INT, @Last INT;

SET @Line = N'Fixed: State_Id 2 name ' + CASE WHEN @Fixed2 = 1 THEN N'changed to "Andhra Pradesh"' ELSE N'already "Andhra Pradesh"' END
          + N'; State_Id 3 code ' + CASE WHEN @Fixed3 = 1 THEN N'changed from KE to KL' ELSE N'already KL' END + N'.';
PRINT @Line;

SET @Line = N'Inserted ' + CAST(@Inserted AS NVARCHAR(12)) + N' row(s)'
          + CASE WHEN @IsIdentity = 1 THEN N' (State_Id is an identity column; inserted with IDENTITY_INSERT)' ELSE N'' END + N':';
PRINT @Line;
SELECT @i = MIN(NewId), @Last = MAX(NewId) FROM @Plan WHERE NewId IS NOT NULL;
WHILE (@i IS NOT NULL AND @i <= @Last)
BEGIN
    SELECT @Line = N'  ' + CAST(NewId AS NVARCHAR(12)) + N'  ' + State_Code + N'  ' + State_Name FROM @Plan WHERE NewId = @i;
    PRINT @Line;
    SET @i = @i + 1;
END

SELECT @Skipped = COUNT(*) FROM @Plan WHERE SkipReason IS NOT NULL;
SET @Line = N'Skipped ' + CAST(@Skipped AS NVARCHAR(12)) + N' row(s)' + CASE WHEN @Skipped > 0 THEN N':' ELSE N'.' END;
PRINT @Line;
SELECT @i = MIN(Seq), @Last = MAX(Seq) FROM @Plan WHERE SkipReason IS NOT NULL;
WHILE (@i IS NOT NULL AND @i <= @Last)
BEGIN
    SET @Line = NULL;
    SELECT @Line = N'  ' + State_Code + N'  ' + State_Name + N': ' + SkipReason FROM @Plan WHERE Seq = @i AND SkipReason IS NOT NULL;
    IF (@Line IS NOT NULL)
        PRINT @Line;
    SET @i = @i + 1;
END

PRINT CASE WHEN @ProcReplaced = 1 THEN N'spr_GetStateMaster replaced: same columns, ORDER BY State_Name (marker StateMaster-S1).'
           ELSE N'spr_GetStateMaster already sorts by State_Name: left unchanged.' END;

-- The check (also in Database/README.md, step S1): 36 rows, no code or name twice, ids 1 to 3 as decided
DECLARE @Rows INT, @CodesTwice INT, @NamesTwice INT;
SELECT @Rows = COUNT(*) FROM dbo.State_Master;
SELECT @CodesTwice = COUNT(*) FROM (SELECT State_Code FROM dbo.State_Master GROUP BY State_Code HAVING COUNT(*) > 1) d;
SELECT @NamesTwice = COUNT(*) FROM (SELECT State_Name FROM dbo.State_Master GROUP BY State_Name HAVING COUNT(*) > 1) d;
SET @Line = N'Check: ' + CAST(@Rows AS NVARCHAR(12)) + N' row(s) (expected 36), ' + CAST(@CodesTwice AS NVARCHAR(12)) + N' code(s) and '
          + CAST(@NamesTwice AS NVARCHAR(12)) + N' name(s) more than once (expected 0 and 0).';
PRINT @Line;

SELECT State_Id, State_Code, State_Name FROM dbo.State_Master ORDER BY State_Name;
GO
