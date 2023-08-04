CREATE PROCEDURE sp_CustomerRevenue @FromYear INT = NULL, @ToYear INT = NULL, @Period VARCHAR(50) = 'Y', @CustomerID INT = NULL 
AS 


DECLARE @TableName VARCHAR(100)
DECLARE @DynamicSQL nvarchar(1500);


    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ErrorLog')
    BEGIN
        CREATE TABLE ErrorLog (
            [ErrorID] INT IDENTITY(1,1) PRIMARY KEY,
            [ErrorNumber] INT,
            [ErrorSeverity] INT,
            [ErrorMessage] VARCHAR(255),
            [CustomerID] INT,
            [Period] VARCHAR(8),
            [CreatedAt] DATETIME
        )
    END


    SET @TableName = 
            CASE 
                WHEN @CustomerID IS NULL THEN 'All_' 
                ELSE CAST(@CustomerID AS VARCHAR(10)) + '_' 
            END +
            ISNULL((SELECT TOP 1 Customer FROM dimension.Customer WHERE [Customer Key] = @CustomerID), 'Unknown') + '_' +
            CAST(@FromYear as varchar(4))  + '_' +
            CAST(@ToYear as varchar(4)) + '_' +
            CASE 
                WHEN @Period IS NULL THEN 'Y'
                WHEN @Period IN ('Month', 'M') THEN 'M'
                WHEN @Period IN ('Quarter', 'Q') THEN 'Q'
                ELSE 'Y'
            END

    SET @DynamicSQL = N'DROP TABLE IF EXISTS dbo.[' + @TableName + ']'
    EXEC (@DynamicSQL);

    SET @DynamicSQL = N'
        CREATE TABLE dbo.[' + @TableName + '] (
            [CustomerID] INT,
            [CustomerName] VARCHAR(50),
            [Period] VARCHAR(8),
            [Revenue] NUMERIC(19, 2)
        )'
    EXEC (@DynamicSQL);


SET @DynamicSQL = N'
    INSERT INTO dbo.[' + @TableName + '] ([CustomerID], [CustomerName], [Period], [Revenue])
    
    SELECT 
        o.[Customer Key] as CustomerID,
        c.[Customer] as CustomerName,
            CASE 
                WHEN ''' + @Period + ''' IN (''Month'', ''M'') THEN CONVERT(VARCHAR(3), DATENAME(MONTH, [Order Date Key])) + '' '' + CAST(YEAR([Order Date Key]) AS VARCHAR(4))
                WHEN ''' + @Period + ''' IN (''Quarter'', ''Q'') THEN ''Q'' + CAST(DATEPART(QUARTER, [Order Date Key]) AS VARCHAR(1)) + '' '' + CAST(YEAR([Order Date Key]) AS VARCHAR(4))
                ELSE CAST(YEAR([Order Date Key]) AS VARCHAR(4))
            END AS Period,
            SUM(Quantity * [Unit Price]) AS Revenue
        FROM [Fact].[Order] as o
            INNER JOIN [Dimension].[Customer] as c
                on o.[Customer Key] = c.[Customer Key]
        WHERE YEAR([Order Date Key]) BETWEEN ''' + CAST(@FromYear AS VARCHAR(4)) + ''' AND ''' + CAST(@ToYear AS VARCHAR(4)) + '''
            AND (''' + CAST(@CustomerID AS NVARCHAR(10)) + ''' IS NULL OR o.[Customer Key] = ''' + CAST(@CustomerID AS NVARCHAR(10)) + ''')
        GROUP BY 
            o.[Customer Key],
            c.Customer,
            CASE 
                WHEN ''' + @Period + ''' IN (''Month'', ''M'') THEN CONVERT(VARCHAR(3), DATENAME(MONTH, [Order Date Key])) + '' '' + CAST(YEAR([Order Date Key]) AS VARCHAR(4))
                WHEN ''' + @Period + ''' IN (''Quarter'', ''Q'') THEN ''Q'' + CAST(DATEPART(QUARTER, [Order Date Key]) AS VARCHAR(1)) + '' '' + CAST(YEAR([Order Date Key]) AS VARCHAR(4))
                ELSE CAST(YEAR([Order Date Key]) AS VARCHAR(4))
            END'
EXEC (@DynamicSQL);

    IF @@ERROR <> 0
    BEGIN
        INSERT INTO ErrorLog ([ErrorNumber], [ErrorSeverity], [ErrorMessage], [CustomerID], [Period], [CreatedAt])
        VALUES (ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_MESSAGE(), @CustomerID, @Period, GETDATE())
    END


GO





