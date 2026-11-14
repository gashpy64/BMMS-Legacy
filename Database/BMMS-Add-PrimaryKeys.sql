/* ============================================================================
   BMMS - Critical fix #6: add primary keys to the two tables that have none
   ----------------------------------------------------------------------------
   Source_Type            PK on SourceTypeCode (already NOT NULL)
   Audit_Trail_SendMail   PK on Audit_Trail_SendMail_Id (the identity column)

   Safe to re-run: each block checks for duplicates first, and skips the table
   if it already has a primary key. A duplicate stops that table's change and
   prints a message instead. Nothing here deletes or edits any data.
   Take a backup first, e.g.
     BACKUP DATABASE BMMS TO DISK = N'C:\Backups\BMMS_before_pk.bak' WITH COPY_ONLY;
   ============================================================================ */

USE [BMMS];
GO

SET NOCOUNT ON;
GO

IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE parent_object_id = OBJECT_ID('dbo.Source_Type') AND type = 'PK')
    PRINT 'Source_Type: already has a primary key - skipped.';
ELSE IF EXISTS (SELECT SourceTypeCode FROM dbo.Source_Type GROUP BY SourceTypeCode HAVING COUNT(*) > 1)
    PRINT 'Source_Type: duplicate SourceTypeCode values found - primary key NOT added. Remove the duplicates first.';
ELSE
BEGIN
    ALTER TABLE dbo.Source_Type ADD CONSTRAINT PK_Source_Type PRIMARY KEY CLUSTERED (SourceTypeCode);
    PRINT 'Source_Type: primary key added.';
END
GO

IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE parent_object_id = OBJECT_ID('dbo.Audit_Trail_SendMail') AND type = 'PK')
    PRINT 'Audit_Trail_SendMail: already has a primary key - skipped.';
ELSE IF EXISTS (SELECT Audit_Trail_SendMail_Id FROM dbo.Audit_Trail_SendMail GROUP BY Audit_Trail_SendMail_Id HAVING COUNT(*) > 1)
    PRINT 'Audit_Trail_SendMail: duplicate Audit_Trail_SendMail_Id values found - primary key NOT added. Investigate first.';
ELSE
BEGIN
    ALTER TABLE dbo.Audit_Trail_SendMail ADD CONSTRAINT PK_Audit_Trail_SendMail PRIMARY KEY CLUSTERED (Audit_Trail_SendMail_Id);
    PRINT 'Audit_Trail_SendMail: primary key added.';
END
GO

-- Confirm: one row per table. PrimaryKey shows the constraint name, or
-- "(no primary key)" if it was not added (check the Messages tab for why).
SELECT DB_NAME() AS CurrentDatabase,
       t.name AS TableName,
       ISNULL(k.name, '(no primary key)') AS PrimaryKey
FROM sys.tables t
LEFT JOIN sys.key_constraints k ON k.parent_object_id = t.object_id AND k.type = 'PK'
WHERE t.name IN ('Source_Type', 'Audit_Trail_SendMail')
ORDER BY t.name;
GO
