function Read-DatFileLines {
    <#
    .SYNOPSIS
    Reads DAT file lines with multi-line field support.

    .DESCRIPTION
    Reads file content and parses lines, handling embedded newlines in fields.
    Returns structured records ready for DataTable population.

    .PARAMETER FilePath
    Path to DAT file.

    .PARAMETER ExpectedFieldCount
    Expected number of fields per record (ImportID + specification fields).

    .EXAMPLE
    $records = Read-DatFileLines -FilePath "C:\Data\Employee.dat" -ExpectedFieldCount 10
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [int]$ExpectedFieldCount
    )

    Write-Verbose "Reading DAT file: $FilePath (Expected fields: $ExpectedFieldCount)"

    $lines = Get-Content -Path $FilePath
    if ($lines.Count -eq 0) {
        Write-Warning "Data file is empty: $FilePath"
        return @()
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
        $values = $accumulatedLine -split '\|', -1  # -1 to keep empty trailing fields
        $linesConsumed = 1

        # Accumulate lines until we have enough fields
        while ($values.Length -lt $ExpectedFieldCount -and ($currentLineIndex + 1) -lt $totalLines) {
            $currentLineIndex++
            $nextLine = $lines[$currentLineIndex]
            $accumulatedLine += "`n" + $nextLine
            $values = $accumulatedLine -split '\|', -1
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
    return $records
}
