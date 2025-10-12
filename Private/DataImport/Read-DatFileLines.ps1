function Read-DatFileLines {
    <#
    .SYNOPSIS
    Reads DAT file lines with multi-line field support.

    .DESCRIPTION
    Reads file content and parses lines, handling embedded newlines in fields.
    Uses ImportID prefix pattern to detect record boundaries.
    Returns structured records ready for DataTable population.

    .PARAMETER FilePath
    Path to DAT file.

    .PARAMETER ExpectedFieldCount
    Expected number of fields per record (ImportID + specification fields).

    .PARAMETER Prefix
    Data file prefix (e.g., "ABC_" from ABC_Employee.dat). Used to detect record boundaries
    by identifying lines starting with this prefix as new records. Optional for backward compatibility.

    .EXAMPLE
    $records = Read-DatFileLines -FilePath "C:\Data\ABC_Employee.dat" -ExpectedFieldCount 10 -Prefix "ABC_"
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [int]$ExpectedFieldCount,

        [Parameter(Mandatory=$false)]
        [string]$Prefix = ""
    )

    Write-Verbose "Reading DAT file: $FilePath (Expected fields: $ExpectedFieldCount)"

    # Ensure $lines is always an array (Get-Content returns scalar String for single-line files)
    $lines = @(Get-Content -Path $FilePath)
    if ($lines.Count -eq 0) {
        Write-Warning "Data file is empty: $FilePath"
        # Use comma operator to force array return (prevents PowerShell unwrapping to null)
        return ,@()
    }

    $records = @()
    $totalLines = $lines.Count
    $currentLineIndex = 0

    while ($currentLineIndex -lt $totalLines) {
        $startLineNumber = $currentLineIndex + 1
        $currentLine = $lines[$currentLineIndex]

        # Skip empty lines
        if ([string]::IsNullOrWhiteSpace($currentLine)) {
            $currentLineIndex++
            continue
        }

        # Start building record
        $accumulatedLine = $currentLine
        # Use .NET Split for reliable pipe splitting (PowerShell -split has issues in some environments)
        $values = $accumulatedLine.Split('|')
        $linesConsumed = 1

        # Accumulate lines until we have enough fields OR next line starts a new record
        while ($values.Length -lt $ExpectedFieldCount -and ($currentLineIndex + 1) -lt $totalLines) {
            $nextLine = $lines[$currentLineIndex + 1]

            # Check if next line starts with ImportID pattern (new record indicator)
            # Build pattern based on prefix (e.g., "ABC_" means records start with "ABC_*|")
            if (-not [string]::IsNullOrWhiteSpace($nextLine)) {
                $importIdPattern = if ($Prefix) {
                    # Use prefix-specific pattern (e.g., ^ABC_[A-Z0-9_-]*\|)
                    "^$([regex]::Escape($Prefix))[A-Z0-9_-]*\|"
                } else {
                    # Generic pattern for backward compatibility (case-sensitive: uppercase letters, digits, _ -)
                    '^[A-Z0-9_-]+\|'
                }

                if ($nextLine -cmatch $importIdPattern) {
                    # Next line looks like a new record, don't accumulate (case-sensitive match)
                    break
                }
            }

            # Continue accumulating - this line is part of current record
            $currentLineIndex++
            $accumulatedLine += "`n" + $nextLine
            $values = $accumulatedLine.Split('|')
            $linesConsumed++
        }

        # Validate final field count
        if ($values.Length -ne $ExpectedFieldCount) {
            $previewLength = 200  # Characters to show in error preview
            $endLineNumber = $startLineNumber + $linesConsumed - 1
            Write-Error "Field count mismatch at lines $startLineNumber-$endLineNumber. Expected $ExpectedFieldCount, got $($values.Length)"
            $preview = $accumulatedLine.Substring(0, [Math]::Min($previewLength, $accumulatedLine.Length))
            Write-Host "FAILED at line $startLineNumber (consumed $linesConsumed lines)" -ForegroundColor Red
            Write-Host "Content preview: $preview..." -ForegroundColor Red
            throw "Field count mismatch at lines $startLineNumber-$endLineNumber. Expected $ExpectedFieldCount fields, got $($values.Length)."
        }

        if ($linesConsumed -gt 1) {
            Write-Host "  Multi-line record at line $startLineNumber (spans $linesConsumed lines)" -ForegroundColor Cyan
        }

        $records += [PSCustomObject]@{
            LineNumber = $startLineNumber
            Values = $values
        }

        $currentLineIndex++
    }

    Write-Verbose "Read $($records.Count) records from file"

    # Return records array. Use comma operator to prevent PowerShell from unwrapping empty arrays
    # This ensures empty arrays are returned as arrays, not null
    ,$records
}
