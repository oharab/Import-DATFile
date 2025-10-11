@{
    Run = @{
        Path = @('.\Tests')
        Exit = $false
        Throw = $false
    }
    Output = @{
        Verbosity = 'Detailed'
    }
    CodeCoverage = @{
        Enabled = $true
        Path = @(
            '.\SqlServerDataImport.psm1',
            '.\Import-DATFile.Common.psm1',
            '.\Private\**\*.ps1',
            '.\Public\**\*.ps1'
        )
        OutputPath = '.\Tests\coverage.xml'
        OutputFormat = 'JaCoCo'
    }
    TestResult = @{
        Enabled = $true
        OutputPath = '.\Tests\testResults.xml'
        OutputFormat = 'NUnitXml'
    }
}
