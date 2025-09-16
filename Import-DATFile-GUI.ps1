# SQL Server Data Import GUI
# User-friendly Windows Forms interface for the Import-DATFile script

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Global variables
$global:DataFolder = ""
$global:ExcelFile = ""
$global:ImportProcess = $null

function Show-ImportGUI {
    # Create main form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "SQL Server Data Import Utility"
    $form.Size = New-Object System.Drawing.Size(600, 500)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.Icon = [System.Drawing.SystemIcons]::Application

    # Title label
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "SQL Server Data Import Utility"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(580, 30)
    $titleLabel.Location = New-Object System.Drawing.Point(10, 10)
    $titleLabel.TextAlign = "MiddleCenter"
    $form.Controls.Add($titleLabel)

    # Subtitle label
    $subtitleLabel = New-Object System.Windows.Forms.Label
    $subtitleLabel.Text = "Import pipe-separated .dat files into SQL Server using Excel specifications"
    $subtitleLabel.Size = New-Object System.Drawing.Size(580, 20)
    $subtitleLabel.Location = New-Object System.Drawing.Point(10, 45)
    $subtitleLabel.TextAlign = "MiddleCenter"
    $subtitleLabel.ForeColor = [System.Drawing.Color]::DarkBlue
    $form.Controls.Add($subtitleLabel)

    # Data folder section
    $dataFolderLabel = New-Object System.Windows.Forms.Label
    $dataFolderLabel.Text = "Data Folder:"
    $dataFolderLabel.Size = New-Object System.Drawing.Size(100, 20)
    $dataFolderLabel.Location = New-Object System.Drawing.Point(20, 85)
    $form.Controls.Add($dataFolderLabel)

    $dataFolderTextBox = New-Object System.Windows.Forms.TextBox
    $dataFolderTextBox.Size = New-Object System.Drawing.Size(380, 20)
    $dataFolderTextBox.Location = New-Object System.Drawing.Point(20, 105)
    $dataFolderTextBox.Text = (Get-Location).Path
    $form.Controls.Add($dataFolderTextBox)

    $dataFolderButton = New-Object System.Windows.Forms.Button
    $dataFolderButton.Text = "Browse..."
    $dataFolderButton.Size = New-Object System.Drawing.Size(80, 25)
    $dataFolderButton.Location = New-Object System.Drawing.Point(410, 103)
    $dataFolderButton.Add_Click({
        $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderDialog.Description = "Select folder containing .dat files"
        $folderDialog.SelectedPath = $dataFolderTextBox.Text
        if ($folderDialog.ShowDialog() -eq "OK") {
            $dataFolderTextBox.Text = $folderDialog.SelectedPath
        }
    })
    $form.Controls.Add($dataFolderButton)

    # Excel file section
    $excelLabel = New-Object System.Windows.Forms.Label
    $excelLabel.Text = "Excel Specification File:"
    $excelLabel.Size = New-Object System.Drawing.Size(150, 20)
    $excelLabel.Location = New-Object System.Drawing.Point(20, 140)
    $form.Controls.Add($excelLabel)

    $excelTextBox = New-Object System.Windows.Forms.TextBox
    $excelTextBox.Size = New-Object System.Drawing.Size(380, 20)
    $excelTextBox.Location = New-Object System.Drawing.Point(20, 160)
    $excelTextBox.Text = "ExportSpec.xlsx"
    $form.Controls.Add($excelTextBox)

    $excelButton = New-Object System.Windows.Forms.Button
    $excelButton.Text = "Browse..."
    $excelButton.Size = New-Object System.Drawing.Size(80, 25)
    $excelButton.Location = New-Object System.Drawing.Point(410, 158)
    $excelButton.Add_Click({
        $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $fileDialog.Filter = "Excel files (*.xlsx;*.xls)|*.xlsx;*.xls|All files (*.*)|*.*"
        $fileDialog.Title = "Select Excel specification file"
        $fileDialog.InitialDirectory = $dataFolderTextBox.Text
        if ($fileDialog.ShowDialog() -eq "OK") {
            $excelTextBox.Text = [System.IO.Path]::GetFileName($fileDialog.FileName)
            if ([System.IO.Path]::GetDirectoryName($fileDialog.FileName) -ne $dataFolderTextBox.Text) {
                [System.Windows.Forms.MessageBox]::Show("Note: Excel file should be in the same folder as your .dat files for best results.", "File Location", "OK", "Information")
            }
        }
    })
    $form.Controls.Add($excelButton)

    # Options section
    $optionsGroupBox = New-Object System.Windows.Forms.GroupBox
    $optionsGroupBox.Text = "Options"
    $optionsGroupBox.Size = New-Object System.Drawing.Size(470, 80)
    $optionsGroupBox.Location = New-Object System.Drawing.Point(20, 195)
    $form.Controls.Add($optionsGroupBox)

    $verboseCheckBox = New-Object System.Windows.Forms.CheckBox
    $verboseCheckBox.Text = "Enable verbose logging (recommended for troubleshooting)"
    $verboseCheckBox.Size = New-Object System.Drawing.Size(450, 20)
    $verboseCheckBox.Location = New-Object System.Drawing.Point(10, 25)
    $optionsGroupBox.Controls.Add($verboseCheckBox)

    $autoSkipCheckBox = New-Object System.Windows.Forms.CheckBox
    $autoSkipCheckBox.Text = "Always skip first field if file has extra columns"
    $autoSkipCheckBox.Size = New-Object System.Drawing.Size(450, 20)
    $autoSkipCheckBox.Location = New-Object System.Drawing.Point(10, 50)
    $optionsGroupBox.Controls.Add($autoSkipCheckBox)

    # Progress section
    $progressLabel = New-Object System.Windows.Forms.Label
    $progressLabel.Text = "Ready to import..."
    $progressLabel.Size = New-Object System.Drawing.Size(470, 20)
    $progressLabel.Location = New-Object System.Drawing.Point(20, 290)
    $form.Controls.Add($progressLabel)

    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Size = New-Object System.Drawing.Size(470, 23)
    $progressBar.Location = New-Object System.Drawing.Point(20, 315)
    $progressBar.Style = "Marquee"
    $progressBar.MarqueeAnimationSpeed = 0
    $form.Controls.Add($progressBar)

    # Output text box
    $outputTextBox = New-Object System.Windows.Forms.TextBox
    $outputTextBox.Multiline = $true
    $outputTextBox.ScrollBars = "Vertical"
    $outputTextBox.Size = New-Object System.Drawing.Size(470, 80)
    $outputTextBox.Location = New-Object System.Drawing.Point(20, 350)
    $outputTextBox.ReadOnly = $true
    $outputTextBox.BackColor = [System.Drawing.Color]::Black
    $outputTextBox.ForeColor = [System.Drawing.Color]::Lime
    $outputTextBox.Font = New-Object System.Drawing.Font("Consolas", 8)
    $form.Controls.Add($outputTextBox)

    # Buttons
    $startButton = New-Object System.Windows.Forms.Button
    $startButton.Text = "Start Import"
    $startButton.Size = New-Object System.Drawing.Size(100, 30)
    $startButton.Location = New-Object System.Drawing.Point(500, 350)
    $startButton.BackColor = [System.Drawing.Color]::LightGreen
    $startButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($startButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Size = New-Object System.Drawing.Size(100, 30)
    $cancelButton.Location = New-Object System.Drawing.Point(500, 390)
    $cancelButton.Enabled = $false
    $form.Controls.Add($cancelButton)

    $exitButton = New-Object System.Windows.Forms.Button
    $exitButton.Text = "Exit"
    $exitButton.Size = New-Object System.Drawing.Size(100, 30)
    $exitButton.Location = New-Object System.Drawing.Point(500, 430)
    $exitButton.Add_Click({ $form.Close() })
    $form.Controls.Add($exitButton)

    # Event handlers
    $startButton.Add_Click({
        # Validate inputs
        if (-not (Test-Path $dataFolderTextBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Data folder does not exist. Please select a valid folder.", "Error", "OK", "Error")
            return
        }

        $excelPath = Join-Path $dataFolderTextBox.Text $excelTextBox.Text
        if (-not (Test-Path $excelPath)) {
            [System.Windows.Forms.MessageBox]::Show("Excel specification file not found in the data folder.", "Error", "OK", "Error")
            return
        }

        # Check for Employee.dat file
        $employeeFiles = Get-ChildItem -Path $dataFolderTextBox.Text -Name "*Employee.dat"
        if ($employeeFiles.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No *Employee.dat file found in the data folder. This file is required for prefix detection.", "Error", "OK", "Error")
            return
        }

        # Disable start button and enable cancel
        $startButton.Enabled = $false
        $cancelButton.Enabled = $true
        $progressBar.MarqueeAnimationSpeed = 30
        $progressLabel.Text = "Import in progress..."
        $outputTextBox.Clear()
        $outputTextBox.AppendText("Starting SQL Server Data Import...`r`n")

        # Build command arguments
        $arguments = @(
            "-DataFolder", "`"$($dataFolderTextBox.Text)`""
            "-ExcelSpecFile", "`"$($excelTextBox.Text)`""
        )

        if ($verboseCheckBox.Checked) {
            $arguments += "-Verbose"
        }

        # Create a background job to run the import
        $scriptPath = Join-Path (Split-Path $MyInvocation.MyCommand.Path) "Import-DATFile.ps1"

        try {
            $global:ImportProcess = Start-Process -FilePath "powershell.exe" -ArgumentList ("-File", "`"$scriptPath`"") + $arguments -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\import-output.txt" -RedirectStandardError "$env:TEMP\import-error.txt"

            # Start a timer to check process status
            $timer = New-Object System.Windows.Forms.Timer
            $timer.Interval = 1000
            $timer.Add_Tick({
                if ($global:ImportProcess.HasExited) {
                    $timer.Stop()
                    $progressBar.MarqueeAnimationSpeed = 0
                    $startButton.Enabled = $true
                    $cancelButton.Enabled = $false

                    if ($global:ImportProcess.ExitCode -eq 0) {
                        $progressLabel.Text = "Import completed successfully!"
                        $progressLabel.ForeColor = [System.Drawing.Color]::Green
                        $outputTextBox.AppendText("Import completed successfully!`r`n")
                    } else {
                        $progressLabel.Text = "Import failed. Check output for details."
                        $progressLabel.ForeColor = [System.Drawing.Color]::Red
                        $outputTextBox.AppendText("Import failed with exit code: $($global:ImportProcess.ExitCode)`r`n")
                    }

                    # Read output files
                    if (Test-Path "$env:TEMP\import-output.txt") {
                        $output = Get-Content "$env:TEMP\import-output.txt" -Raw
                        $outputTextBox.AppendText($output)
                    }
                    if (Test-Path "$env:TEMP\import-error.txt") {
                        $errorContent = Get-Content "$env:TEMP\import-error.txt" -Raw
                        if ($errorContent) {
                            $outputTextBox.AppendText("Errors:`r`n$errorContent")
                        }
                    }

                    $global:ImportProcess = $null
                }
            })
            $timer.Start()
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to start import process: $($_.Exception.Message)", "Error", "OK", "Error")
            $startButton.Enabled = $true
            $cancelButton.Enabled = $false
            $progressBar.MarqueeAnimationSpeed = 0
            $progressLabel.Text = "Ready to import..."
        }
    })

    $cancelButton.Add_Click({
        if ($global:ImportProcess -and -not $global:ImportProcess.HasExited) {
            $result = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to cancel the import?", "Confirm Cancel", "YesNo", "Question")
            if ($result -eq "Yes") {
                $global:ImportProcess.Kill()
                $progressBar.MarqueeAnimationSpeed = 0
                $progressLabel.Text = "Import cancelled by user."
                $progressLabel.ForeColor = [System.Drawing.Color]::Orange
                $startButton.Enabled = $true
                $cancelButton.Enabled = $false
                $outputTextBox.AppendText("Import cancelled by user.`r`n")
            }
        }
    })

    # Show the form
    $form.ShowDialog()
}

# Check if Import-DATFile.ps1 exists
$scriptPath = Join-Path (Split-Path $MyInvocation.MyCommand.Path) "Import-DATFile.ps1"
if (-not (Test-Path $scriptPath)) {
    [System.Windows.Forms.MessageBox]::Show("Import-DATFile.ps1 not found in the same directory as this GUI script.", "Error", "OK", "Error")
    exit 1
}

# Show the GUI
Show-ImportGUI