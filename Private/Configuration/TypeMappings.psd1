# TypeMappings.psd1
# Data type mappings for Import-DATFile system
# This configuration file allows type mappings to be modified without code changes
# Following the Open/Closed Principle - open for extension, closed for modification

@{
    # SQL Server Type Mappings
    # Maps Excel/specification data types to SQL Server data types
    # Order matters - patterns are evaluated in order, first match wins
    SqlTypeMappings = @(
        @{
            Name = 'MONEY'
            Pattern = '^MONEY$'
            SqlType = 'MONEY'
            UsesPrecision = $false
        },
        @{
            Name = 'VARCHAR'
            Pattern = '^VARCHAR.*'
            SqlType = 'VARCHAR'
            UsesPrecision = $true
            DefaultPrecision = '255'
        },
        @{
            Name = 'CHAR'
            Pattern = '^CHAR.*'
            SqlType = 'CHAR'
            UsesPrecision = $true
            DefaultPrecision = '10'
        },
        @{
            Name = 'INT'
            Pattern = '^INT.*|^INTEGER$'
            SqlType = 'INT'
            UsesPrecision = $false
        },
        @{
            Name = 'BIGINT'
            Pattern = '^BIGINT$'
            SqlType = 'BIGINT'
            UsesPrecision = $false
        },
        @{
            Name = 'SMALLINT'
            Pattern = '^SMALLINT$'
            SqlType = 'SMALLINT'
            UsesPrecision = $false
        },
        @{
            Name = 'TINYINT'
            Pattern = '^TINYINT$'
            SqlType = 'TINYINT'
            UsesPrecision = $false
        },
        @{
            Name = 'DECIMAL'
            Pattern = '^DECIMAL.*|^NUMERIC.*'
            SqlType = 'DECIMAL'
            UsesPrecision = $true
            DefaultPrecision = '18,2'
        },
        @{
            Name = 'FLOAT'
            Pattern = '^FLOAT$'
            SqlType = 'FLOAT'
            UsesPrecision = $false
        },
        @{
            Name = 'REAL'
            Pattern = '^REAL$'
            SqlType = 'REAL'
            UsesPrecision = $false
        },
        @{
            Name = 'DATE'
            Pattern = '^DATE$'
            SqlType = 'DATE'
            UsesPrecision = $false
        },
        @{
            Name = 'DATETIME'
            Pattern = '^DATETIME.*'
            SqlType = 'DATETIME2'
            UsesPrecision = $false
        },
        @{
            Name = 'TIME'
            Pattern = '^TIME$'
            SqlType = 'TIME'
            UsesPrecision = $false
        },
        @{
            Name = 'BIT'
            Pattern = '^BIT$|^BOOLEAN$'
            SqlType = 'BIT'
            UsesPrecision = $false
        },
        @{
            Name = 'TEXT'
            Pattern = '^TEXT$'
            SqlType = 'NVARCHAR(MAX)'
            UsesPrecision = $false
        }
    )

    # .NET Type Mappings
    # Maps SQL Server types to .NET Framework types for DataTable columns
    DotNetTypeMappings = @{
        'DATE' = 'System.DateTime'
        'DATETIME' = 'System.DateTime'
        'DATETIME2' = 'System.DateTime'
        'TIME' = 'System.DateTime'
        'INT' = 'System.Int32'
        'INTEGER' = 'System.Int32'
        'SMALLINT' = 'System.Int32'
        'TINYINT' = 'System.Int32'
        'BIGINT' = 'System.Int64'
        'FLOAT' = 'System.Double'
        'DOUBLE' = 'System.Double'
        'REAL' = 'System.Single'
        'DECIMAL' = 'System.Decimal'
        'NUMERIC' = 'System.Decimal'
        'MONEY' = 'System.Decimal'
        'BIT' = 'System.Boolean'
        'BOOLEAN' = 'System.Boolean'
    }

    # Default fallback types when no match is found
    DefaultSqlType = 'NVARCHAR(255)'
    DefaultDotNetType = 'System.String'
}
