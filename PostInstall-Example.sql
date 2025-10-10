-- Example Post-Install Script
-- This script demonstrates how to use post-install scripts with placeholders
-- Place SQL files like this in a folder and specify the folder path with -PostInstallScripts parameter

-- Placeholders available:
-- {{DATABASE}} - Will be replaced with the database name
-- {{SCHEMA}} - Will be replaced with the schema name

USE {{DATABASE}}
GO

-- Example 1: Create a view that summarizes employee data
CREATE OR ALTER VIEW {{SCHEMA}}.vw_EmployeeSummary AS
SELECT
    e.ImportID,
    e.FirstName,
    e.LastName,
    e.Department,
    e.HireDate,
    DATEDIFF(YEAR, e.HireDate, GETDATE()) AS YearsOfService
FROM {{SCHEMA}}.Employee e
WHERE e.Active = 1
GO

-- Example 2: Create a stored procedure
CREATE OR ALTER PROCEDURE {{SCHEMA}}.usp_GetEmployeesByDepartment
    @Department NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ImportID,
        FirstName,
        LastName,
        HireDate,
        Department
    FROM {{SCHEMA}}.Employee
    WHERE Department = @Department
        AND Active = 1
    ORDER BY LastName, FirstName
END
GO

-- Example 3: Create an index for better performance
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Employee_Department'
        AND object_id = OBJECT_ID('{{SCHEMA}}.Employee')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_Employee_Department
    ON {{SCHEMA}}.Employee (Department)
    INCLUDE (FirstName, LastName, Active)
END
GO

PRINT 'Post-install script completed successfully for schema {{SCHEMA}}'
