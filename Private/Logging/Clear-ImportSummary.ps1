function Clear-ImportSummary {
    <#
    .SYNOPSIS
    Clears import summary.

    .EXAMPLE
    Clear-ImportSummary
    #>
    [CmdletBinding()]
    param()

    $script:ImportSummary = @()
}
