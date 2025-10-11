function Test-ImportPath {
    <#
    .SYNOPSIS
    Validates a file or folder path for import operations.

    .DESCRIPTION
    Provides consistent path validation with clear error messages.
    Supports validating both files and folders.

    .PARAMETER Path
    Path to validate.

    .PARAMETER PathType
    Type of path to validate: 'File' or 'Folder'.

    .PARAMETER ThrowOnError
    If specified, throws an exception on validation failure.
    Otherwise, returns false.

    .EXAMPLE
    Test-ImportPath -Path "C:\Data" -PathType Folder -ThrowOnError

    .EXAMPLE
    if (-not (Test-ImportPath -Path "C:\Data\file.xlsx" -PathType File)) {
        Write-Host "File not found"
    }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [ValidateSet('File', 'Folder')]
        [string]$PathType,

        [switch]$ThrowOnError
    )

    $exists = $false
    $message = ""

    switch ($PathType) {
        'File' {
            $exists = Test-Path -Path $Path -PathType Leaf
            if (-not $exists) {
                $message = "File not found: $Path"
            }
        }
        'Folder' {
            $exists = Test-Path -Path $Path -PathType Container
            if (-not $exists) {
                $message = "Folder not found: $Path"
            }
        }
    }

    if (-not $exists) {
        if ($ThrowOnError) {
            throw $message
        }
        else {
            Write-Error $message
            return $false
        }
    }

    Write-Verbose "$PathType validated: $Path"
    return $true
}
