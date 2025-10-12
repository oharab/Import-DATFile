# TypeMapping.Tests.ps1
# Characterization tests for type mapping functions
# Tests Get-SqlDataTypeMapping and Get-DotNetDataType

BeforeAll {
    # Get module root
    $moduleRoot = Join-Path $PSScriptRoot "..\..\.."

    # Dot-source Private functions needed for testing
    . (Join-Path $moduleRoot "Private\DataImport\Get-SqlDataTypeMapping.ps1")
    . (Join-Path $moduleRoot "Private\DataImport\Get-DotNetDataType.ps1")
}

Describe "Get-SqlDataTypeMapping" {

    Context "String Types" {
        It "Should map VARCHAR with precision" {
            $result = Get-SqlDataTypeMapping -ExcelType "VARCHAR" -Precision "100"
            $result | Should -Be "VARCHAR(100)"
        }

        It "Should map VARCHAR without precision to default" {
            $result = Get-SqlDataTypeMapping -ExcelType "VARCHAR" -Precision ""
            $result | Should -Be "VARCHAR(255)"  # Document exact default precision
        }

        It "Should map NVARCHAR to default (not explicitly defined)" {
            $result = Get-SqlDataTypeMapping -ExcelType "NVARCHAR" -Precision "200" -WarningAction SilentlyContinue
            $result | Should -Be "NVARCHAR(255)"  # Falls back to default
        }

        It "Should map CHAR with precision" {
            $result = Get-SqlDataTypeMapping -ExcelType "CHAR" -Precision "10"
            $result | Should -Be "CHAR(10)"
        }

        It "Should map NCHAR to default (not explicitly defined)" {
            $result = Get-SqlDataTypeMapping -ExcelType "NCHAR" -Precision "10" -WarningAction SilentlyContinue
            $result | Should -Be "NVARCHAR(255)"  # Falls back to default
        }

        It "Should map TEXT type to NVARCHAR(MAX)" {
            $result = Get-SqlDataTypeMapping -ExcelType "TEXT"
            $result | Should -Be "NVARCHAR(MAX)"
        }

        It "Should map NTEXT to default (not explicitly defined)" {
            $result = Get-SqlDataTypeMapping -ExcelType "NTEXT" -WarningAction SilentlyContinue
            $result | Should -Be "NVARCHAR(255)"  # Falls back to default
        }
    }

    Context "Integer Types" {
        It "Should map INT type" {
            $result = Get-SqlDataTypeMapping -ExcelType "INT"
            $result | Should -Be "INT"
        }

        It "Should map INTEGER type" {
            $result = Get-SqlDataTypeMapping -ExcelType "INTEGER"
            $result | Should -Be "INT"
        }

        It "Should map BIGINT type" {
            $result = Get-SqlDataTypeMapping -ExcelType "BIGINT"
            $result | Should -Be "BIGINT"
        }

        It "Should map SMALLINT type" {
            $result = Get-SqlDataTypeMapping -ExcelType "SMALLINT"
            $result | Should -Be "SMALLINT"
        }

        It "Should map TINYINT type" {
            $result = Get-SqlDataTypeMapping -ExcelType "TINYINT"
            $result | Should -Be "TINYINT"
        }
    }

    Context "Decimal Types" {
        It "Should map DECIMAL with precision" {
            $result = Get-SqlDataTypeMapping -ExcelType "DECIMAL" -Precision "10,2"
            $result | Should -Be "DECIMAL(10,2)"
        }

        It "Should map NUMERIC with precision" {
            $result = Get-SqlDataTypeMapping -ExcelType "NUMERIC" -Precision "18,4"
            $result | Should -Be "DECIMAL(18,4)"  # NUMERIC pattern maps to DECIMAL
        }

        It "Should map MONEY type" {
            $result = Get-SqlDataTypeMapping -ExcelType "MONEY"
            $result | Should -Be "MONEY"
        }

        It "Should map SMALLMONEY to default (not explicitly defined)" {
            $result = Get-SqlDataTypeMapping -ExcelType "SMALLMONEY" -WarningAction SilentlyContinue
            $result | Should -Be "NVARCHAR(255)"  # Falls back to default
        }
    }

    Context "Floating Point Types" {
        It "Should map FLOAT type" {
            $result = Get-SqlDataTypeMapping -ExcelType "FLOAT"
            $result | Should -Be "FLOAT"
        }

        It "Should map REAL type" {
            $result = Get-SqlDataTypeMapping -ExcelType "REAL"
            $result | Should -Be "REAL"
        }
    }

    Context "Date and Time Types" {
        It "Should map DATE type" {
            $result = Get-SqlDataTypeMapping -ExcelType "DATE"
            $result | Should -Be "DATE"
        }

        It "Should map DATETIME type to DATETIME2" {
            $result = Get-SqlDataTypeMapping -ExcelType "DATETIME"
            $result | Should -Be "DATETIME2"  # Mapped to DATETIME2 in config
        }

        It "Should map DATETIME2 type to DATETIME2" {
            $result = Get-SqlDataTypeMapping -ExcelType "DATETIME2"
            $result | Should -Be "DATETIME2"
        }

        It "Should map TIME type" {
            $result = Get-SqlDataTypeMapping -ExcelType "TIME"
            $result | Should -Be "TIME"
        }

        It "Should map SMALLDATETIME to default (not explicitly defined)" {
            $result = Get-SqlDataTypeMapping -ExcelType "SMALLDATETIME" -WarningAction SilentlyContinue
            $result | Should -Be "NVARCHAR(255)"  # Falls back to default
        }
    }

    Context "Boolean and Binary Types" {
        It "Should map BIT type" {
            $result = Get-SqlDataTypeMapping -ExcelType "BIT"
            $result | Should -Be "BIT"
        }

        It "Should map BINARY to default (not explicitly defined)" {
            $result = Get-SqlDataTypeMapping -ExcelType "BINARY" -Precision "50" -WarningAction SilentlyContinue
            $result | Should -Be "NVARCHAR(255)"  # Falls back to default
        }

        It "Should map VARBINARY to default (not explicitly defined)" {
            $result = Get-SqlDataTypeMapping -ExcelType "VARBINARY" -Precision "MAX" -WarningAction SilentlyContinue
            $result | Should -Be "NVARCHAR(255)"  # Falls back to default
        }
    }

    Context "Case Insensitivity" {
        It "Should map lowercase type names" {
            $result = Get-SqlDataTypeMapping -ExcelType "int"
            $result | Should -Be "INT"
        }

        It "Should map mixed case type names" {
            $result = Get-SqlDataTypeMapping -ExcelType "VarChar" -Precision "50"
            $result | Should -Be "VARCHAR(50)"
        }
    }

    Context "Unknown Types" {
        It "Should default unknown type to NVARCHAR(255)" {
            $result = Get-SqlDataTypeMapping -ExcelType "UNKNOWN_TYPE" -WarningAction SilentlyContinue
            $result | Should -Be "NVARCHAR(255)"  # Current default is NVARCHAR(255)
        }

        It "Should default invalid type to NVARCHAR(255)" {
            $result = Get-SqlDataTypeMapping -ExcelType "INVALIDTYPE123" -WarningAction SilentlyContinue
            $result | Should -Be "NVARCHAR(255)"  # Current default is NVARCHAR(255)
        }
    }
}

Describe "Get-DotNetDataType" {

    Context "String Types" {
        It "Should map VARCHAR to System.String" {
            $result = Get-DotNetDataType -SqlType "VARCHAR"
            $result | Should -Be ([System.String])
        }

        It "Should map VARCHAR with precision to System.String" {
            $result = Get-DotNetDataType -SqlType "VARCHAR(100)"
            $result | Should -Be ([System.String])
        }

        It "Should map NVARCHAR to System.String" {
            $result = Get-DotNetDataType -SqlType "NVARCHAR"
            $result | Should -Be ([System.String])
        }

        It "Should map CHAR to System.String" {
            $result = Get-DotNetDataType -SqlType "CHAR"
            $result | Should -Be ([System.String])
        }

        It "Should map TEXT to System.String" {
            $result = Get-DotNetDataType -SqlType "TEXT"
            $result | Should -Be ([System.String])
        }
    }

    Context "Integer Types" {
        It "Should map INT to System.Int32" {
            $result = Get-DotNetDataType -SqlType "INT"
            $result | Should -Be ([System.Int32])
        }

        It "Should map BIGINT to System.Int64" {
            $result = Get-DotNetDataType -SqlType "BIGINT"
            $result | Should -Be ([System.Int64])
        }

        It "Should map SMALLINT to System.Int32 (current mapping)" {
            $result = Get-DotNetDataType -SqlType "SMALLINT"
            $result | Should -Be ([System.Int32])  # Mapped to Int32, not Int16
        }

        It "Should map TINYINT to System.Int32 (current mapping)" {
            $result = Get-DotNetDataType -SqlType "TINYINT"
            $result | Should -Be ([System.Int32])  # Mapped to Int32, not Byte
        }
    }

    Context "Decimal Types" {
        It "Should map DECIMAL to System.Decimal" {
            $result = Get-DotNetDataType -SqlType "DECIMAL"
            $result | Should -Be ([System.Decimal])
        }

        It "Should map DECIMAL with precision to System.Decimal" {
            $result = Get-DotNetDataType -SqlType "DECIMAL(10,2)"
            $result | Should -Be ([System.Decimal])
        }

        It "Should map NUMERIC to System.Decimal" {
            $result = Get-DotNetDataType -SqlType "NUMERIC"
            $result | Should -Be ([System.Decimal])
        }

        It "Should map MONEY to System.Decimal" {
            $result = Get-DotNetDataType -SqlType "MONEY"
            $result | Should -Be ([System.Decimal])
        }
    }

    Context "Floating Point Types" {
        It "Should map FLOAT to System.Double" {
            $result = Get-DotNetDataType -SqlType "FLOAT"
            $result | Should -Be ([System.Double])
        }

        It "Should map REAL to System.Single" {
            $result = Get-DotNetDataType -SqlType "REAL"
            $result | Should -Be ([System.Single])
        }
    }

    Context "Date and Time Types" {
        It "Should map DATE to System.DateTime" {
            $result = Get-DotNetDataType -SqlType "DATE"
            $result | Should -Be ([System.DateTime])
        }

        It "Should map DATETIME to System.DateTime" {
            $result = Get-DotNetDataType -SqlType "DATETIME"
            $result | Should -Be ([System.DateTime])
        }

        It "Should map DATETIME2 to System.DateTime" {
            $result = Get-DotNetDataType -SqlType "DATETIME2"
            $result | Should -Be ([System.DateTime])
        }
    }

    Context "Boolean and Binary Types" {
        It "Should map BIT to System.Boolean" {
            $result = Get-DotNetDataType -SqlType "BIT"
            $result | Should -Be ([System.Boolean])
        }

        It "Should map BINARY to System.String (not explicitly defined)" {
            $result = Get-DotNetDataType -SqlType "BINARY"
            $result | Should -Be ([System.String])  # Falls back to default
        }

        It "Should map VARBINARY to System.String (not explicitly defined)" {
            $result = Get-DotNetDataType -SqlType "VARBINARY"
            $result | Should -Be ([System.String])  # Falls back to default
        }
    }

    Context "Case Insensitivity" {
        It "Should map lowercase SQL types" {
            $result = Get-DotNetDataType -SqlType "int"
            $result | Should -Be ([System.Int32])
        }

        It "Should map mixed case SQL types" {
            $result = Get-DotNetDataType -SqlType "VarChar"
            $result | Should -Be ([System.String])
        }
    }

    Context "Unknown Types" {
        It "Should default unknown type to System.String" {
            $result = Get-DotNetDataType -SqlType "UNKNOWN_SQL_TYPE"
            $result | Should -Be ([System.String])
        }
    }

    Context "Type Extraction from Precision" {
        It "Should extract base type from VARCHAR(100)" {
            $result = Get-DotNetDataType -SqlType "VARCHAR(100)"
            $result | Should -Be ([System.String])
        }

        It "Should extract base type from DECIMAL(18,2)" {
            $result = Get-DotNetDataType -SqlType "DECIMAL(18,2)"
            $result | Should -Be ([System.Decimal])
        }

        It "Should extract base type from NVARCHAR(MAX)" {
            $result = Get-DotNetDataType -SqlType "NVARCHAR(MAX)"
            $result | Should -Be ([System.String])
        }
    }
}
