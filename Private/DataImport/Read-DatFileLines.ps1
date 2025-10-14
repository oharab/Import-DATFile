function Read-DatFileLines {
    <#
    .SYNOPSIS
    Reads DAT file lines with multi-line field support using streaming I/O.

    .DESCRIPTION
    Reads file content using StreamReader for memory-efficient processing.
    Handles embedded newlines in fields by accumulating lines until expected
    field count is reached. Supports files larger than available RAM.

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

    .NOTES
    Uses System.IO.StreamReader for memory-efficient streaming.
    Memory usage: ~few KB regardless of file size (vs loading entire file into memory).
    Supports files larger than available RAM.
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

    Write-Verbose "Reading DAT file (streaming): $FilePath (Expected fields: $ExpectedFieldCount)"

    $records = @()
    $reader = $null
    $currentRecord = $null
    $lineNumber = 0

    try {
        # Create StreamReader for memory-efficient line-by-line reading
        $reader = [System.IO.StreamReader]::new($FilePath)

        while (($line = $reader.ReadLine()) -ne $null) {
            $lineNumber++

            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }

            # Check if this line starts a new record (ImportID pattern)
            $isNewRecord = $false
            if ($currentRecord) {
                # Build ImportID detection pattern
                $importIdPattern = if ($Prefix) {
                    # Use prefix-specific pattern (e.g., ^ABC_[A-Z0-9_-]*\|)
                    "^$([regex]::Escape($Prefix))[A-Z0-9_-]*\|"
                } else {
                    # Generic pattern for backward compatibility (case-sensitive)
                    '^[A-Z0-9_-]+\|'
                }

                # Check if line matches ImportID pattern (new record indicator)
                if ($line -cmatch $importIdPattern) {
                    $isNewRecord = $true
                }
            }

            # If new record detected and we have a current record, complete it first
            if ($isNewRecord) {
                # Complete previous record
                $completedRecord = Complete-Record -RecordData $currentRecord -ExpectedFieldCount $ExpectedFieldCount
                $records += $completedRecord

                # Start new record with current line
                $currentRecord = @{
                    StartLine = $lineNumber
                    AccumulatedLine = $line
                    LinesConsumed = 1
                }
            }
            elseif ($currentRecord) {
                # Continue accumulating lines into current record
                $currentRecord.AccumulatedLine += "`n" + $line
                $currentRecord.LinesConsumed++

                # Check if we've reached expected field count
                $values = $currentRecord.AccumulatedLine.Split('|')
                if ($values.Length -eq $ExpectedFieldCount) {
                    # Record is complete
                    $completedRecord = Complete-Record -RecordData $currentRecord -ExpectedFieldCount $ExpectedFieldCount
                    $records += $completedRecord
                    $currentRecord = $null
                }
            }
            else {
                # Start first record
                $currentRecord = @{
                    StartLine = $lineNumber
                    AccumulatedLine = $line
                    LinesConsumed = 1
                }

                # Check if single-line record is already complete
                $values = $currentRecord.AccumulatedLine.Split('|')
                if ($values.Length -eq $ExpectedFieldCount) {
                    $completedRecord = Complete-Record -RecordData $currentRecord -ExpectedFieldCount $ExpectedFieldCount
                    $records += $completedRecord
                    $currentRecord = $null
                }
            }
        }

        # Handle final record if any
        if ($currentRecord) {
            $completedRecord = Complete-Record -RecordData $currentRecord -ExpectedFieldCount $ExpectedFieldCount
            $records += $completedRecord
        }

        Write-Verbose "Read $($records.Count) records from file (streaming mode)"

        # Return records array. Use comma operator to prevent PowerShell from unwrapping empty arrays
        # This ensures empty arrays are returned as arrays, not null
        ,$records
    }
    catch {
        Write-Error "Failed to read DAT file: $($_.Exception.Message)"
        throw
    }
    finally {
        # Ensure StreamReader is always disposed
        if ($reader) {
            $reader.Dispose()
        }
    }
}

function Complete-Record {
    <#
    .SYNOPSIS
    Completes and validates a record from accumulated data.

    .DESCRIPTION
    Internal helper function to validate field count and create final record object.

    .PARAMETER RecordData
    Hashtable with StartLine, AccumulatedLine, LinesConsumed.

    .PARAMETER ExpectedFieldCount
    Expected number of fields.

    .OUTPUTS
    PSCustomObject with LineNumber and Values properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$RecordData,

        [Parameter(Mandatory=$true)]
        [int]$ExpectedFieldCount
    )

    $values = $RecordData.AccumulatedLine.Split('|')

    # Validate field count
    if ($values.Length -ne $ExpectedFieldCount) {
        $previewLength = 200  # Characters to show in error preview
        $startLine = $RecordData.StartLine
        $endLine = $startLine + $RecordData.LinesConsumed - 1
        $preview = $RecordData.AccumulatedLine.Substring(0, [Math]::Min($previewLength, $RecordData.AccumulatedLine.Length))

        # Build comprehensive error message with all context
        $errorMessage = @"
Field count mismatch at lines $startLine-$endLine.
Expected: $ExpectedFieldCount fields
Got: $($values.Length) fields
Consumed: $($RecordData.LinesConsumed) line(s)
Content preview: $preview...
"@

        throw $errorMessage
    }

    # Log multi-line records
    if ($RecordData.LinesConsumed -gt 1) {
        Write-Verbose "Multi-line record at line $($RecordData.StartLine) (spans $($RecordData.LinesConsumed) lines)"
    }

    # Return completed record
    return [PSCustomObject]@{
        LineNumber = $RecordData.StartLine
        Values = $values
    }
}
