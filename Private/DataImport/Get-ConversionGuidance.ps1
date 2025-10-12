function Get-ConversionGuidance {
    <#
    .SYNOPSIS
    Provides user-friendly guidance for type conversion failures.

    .DESCRIPTION
    Returns actionable guidance messages based on the target type and failed value.
    Helps users understand why conversion failed and how to fix data issues.

    .PARAMETER Value
    The value that failed to convert.

    .PARAMETER TargetType
    The .NET type that conversion was attempted to.

    .PARAMETER FieldName
    Optional field name for context.

    .PARAMETER TableName
    Optional table name for context.

    .PARAMETER RowNumber
    Optional row number for context.

    .EXAMPLE
    Get-ConversionGuidance -Value "abc" -TargetType ([int]) -FieldName "EmployeeID"

    .OUTPUTS
    String with guidance message.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory=$true)]
        [Type]$TargetType,

        [Parameter(Mandatory=$false)]
        [string]$FieldName,

        [Parameter(Mandatory=$false)]
        [string]$TableName,

        [Parameter(Mandatory=$false)]
        [int]$RowNumber
    )

    # Build context prefix
    $context = @()
    if ($TableName) { $context += "Table '$TableName'" }
    if ($FieldName) { $context += "Field '$FieldName'" }
    if ($RowNumber -gt 0) { $context += "Row $RowNumber" }

    $contextPrefix = if ($context.Count -gt 0) {
        "[$($context -join ', ')] "
    } else {
        ""
    }

    # Build guidance based on target type
    $guidance = switch ($TargetType.Name) {
        { $_ -in @('Int32', 'Int64', 'Byte', 'Int16') } {
            @"
${contextPrefix}Failed to convert value '$Value' to integer.

Expected format: Whole numbers (e.g., 123, -456, 0)
Accepted formats:
  - Plain integers: 123
  - Decimal notation: 123.0 (decimal part must be zero)
  - Negative values: -456

Common issues:
  - Non-numeric characters (e.g., 'abc', '12.5.6')
  - Decimal values with non-zero fractional part (e.g., '12.5')
  - Empty or whitespace-only values
  - Values outside valid range (Int32: -2,147,483,648 to 2,147,483,647)

Fix: Ensure the source data contains valid integer values.
"@
        }

        { $_ -in @('Decimal', 'Double', 'Single') } {
            @"
${contextPrefix}Failed to convert value '$Value' to decimal.

Expected format: Numeric values with decimal point separator '.' (period)
Accepted formats:
  - Integers: 123
  - Decimals: 123.45
  - Negative values: -456.78
  - Scientific notation: 1.23e10

Common issues:
  - Wrong decimal separator (e.g., '123,45' instead of '123.45')
  - Non-numeric characters (e.g., 'abc', '$123.45')
  - Empty or whitespace-only values
  - Multiple decimal points (e.g., '12.34.56')

Fix: Use period (.) as decimal separator and ensure values are numeric.
Note: This module uses InvariantCulture to avoid locale issues.
"@
        }

        'DateTime' {
            @"
${contextPrefix}Failed to convert value '$Value' to date/time.

Supported formats (in order of precedence):
  1. ISO 8601: yyyy-MM-dd HH:mm:ss.fff (e.g., '2024-10-12 14:30:00.123')
  2. ISO 8601: yyyy-MM-ddTHH:mm:ss.fff (e.g., '2024-10-12T14:30:00.123')
  3. ISO 8601: yyyy-MM-dd HH:mm:ss (e.g., '2024-10-12 14:30:00')
  4. ISO 8601: yyyy-MM-ddTHH:mm:ss (e.g., '2024-10-12T14:30:00')
  5. Date only: yyyy-MM-dd (e.g., '2024-10-12')

Common issues:
  - Wrong date format (e.g., 'MM/dd/yyyy' instead of 'yyyy-MM-dd')
  - Invalid dates (e.g., '2024-02-30')
  - Empty or whitespace-only values
  - Ambiguous formats (e.g., '10/12/2024' - is this Oct 12 or Dec 10?)

Fix: Use ISO 8601 format (yyyy-MM-dd) for consistent date parsing.
Note: This module uses InvariantCulture to avoid locale issues.
"@
        }

        'Boolean' {
            @"
${contextPrefix}Failed to convert value '$Value' to boolean.

Accepted values:
  - True: '1', 'TRUE', 'True', 'true', 'YES', 'Yes', 'yes', 'Y', 'y', 'T', 't'
  - False: '0', 'FALSE', 'False', 'false', 'NO', 'No', 'no', 'N', 'n', 'F', 'f'

Common issues:
  - Unexpected value (e.g., 'maybe', 'X', '2')
  - Empty or whitespace-only values
  - Numeric values other than 0 or 1

Fix: Use standard boolean representations (1/0, TRUE/FALSE, YES/NO, Y/N).
"@
        }

        default {
            @"
${contextPrefix}Failed to convert value '$Value' to type $($TargetType.Name).

Check your data source for invalid or unexpected values.
Ensure the Excel specification file defines the correct data type for this field.
"@
        }
    }

    return $guidance.Trim()
}
