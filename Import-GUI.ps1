# SQL Server Data Import - Graphical User Interface (Refactored)
# User-friendly Windows Forms interface using refactored SqlServerDataImport module

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#region Module Loading

# Import core module (which will initialize dependencies automatically)
$moduleDir = Split-Path $MyInvocation.MyCommand.Path
$coreModulePath = Join-Path $moduleDir "SqlServerDataImport.psm1"

if (-not (Test-Path $coreModulePath)) {
    [System.Windows.Forms.MessageBox]::Show("SqlServerDataImport.psm1 module not found at: $coreModulePath", "Error", "OK", "Error")
    exit 1
}

try {
    Import-Module $coreModulePath -Force -ErrorAction Stop
}
catch {
    [System.Windows.Forms.MessageBox]::Show("Failed to load SqlServerDataImport module. This could be due to missing dependencies (SqlServer, ImportExcel modules).`n`nError: $($_.Exception.Message)`n`nTo install required modules, run: Install-Module -Name SqlServer, ImportExcel", "Module Load Error", "OK", "Error")
    exit 1
}

#endregion

# Global variables
$global:ImportRunspace = $null
$global:ImportPowerShell = $null

function Show-ImportGUI {
    # Create main form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "SQL Server Data Import Utility (Refactored)"
    $form.Size = New-Object System.Drawing.Size(620, 760)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.Icon = [System.Drawing.SystemIcons]::Application

    # Title label
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "SQL Server Data Import Utility (Refactored)"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(580, 30)
    $titleLabel.Location = New-Object System.Drawing.Point(10, 10)
    $titleLabel.TextAlign = "MiddleCenter"
    $form.Controls.Add($titleLabel)

    # Subtitle label
    $subtitleLabel = New-Object System.Windows.Forms.Label
    $subtitleLabel.Text = "Fast import with ImportID assumption - No fallbacks, SqlBulkCopy only"
    $subtitleLabel.Size = New-Object System.Drawing.Size(580, 20)
    $subtitleLabel.Location = New-Object System.Drawing.Point(10, 45)
    $subtitleLabel.TextAlign = "MiddleCenter"
    $subtitleLabel.ForeColor = [System.Drawing.Color]::DarkBlue
    $form.Controls.Add($subtitleLabel)

    # Warning section
    $warningGroupBox = New-Object System.Windows.Forms.GroupBox
    $warningGroupBox.Text = "⚠️ IMPORTANT: Optimized Import Assumptions"
    $warningGroupBox.Size = New-Object System.Drawing.Size(580, 95)
    $warningGroupBox.Location = New-Object System.Drawing.Point(10, 75)
    $warningGroupBox.ForeColor = [System.Drawing.Color]::DarkRed
    $form.Controls.Add($warningGroupBox)

    $warningLabel = New-Object System.Windows.Forms.Label
    $warningLabel.Text = @"
• Every data file MUST have ImportID as the first field
• Field count MUST match exactly: ImportID + specification fields
• Multi-line fields with embedded newlines are fully supported
• Only SqlBulkCopy is used - no fallback to INSERT statements
• Dates: yyyy-MM-dd format | Decimals: period separator | NULL: case-insensitive
• No file logging for maximum speed - console output only
"@
    $warningLabel.Size = New-Object System.Drawing.Size(560, 70)
    $warningLabel.Location = New-Object System.Drawing.Point(10, 15)
    $warningLabel.ForeColor = [System.Drawing.Color]::DarkRed
    $warningGroupBox.Controls.Add($warningLabel)

    # Data folder section
    $dataFolderLabel = New-Object System.Windows.Forms.Label
    $dataFolderLabel.Text = "Data Folder:"
    $dataFolderLabel.Size = New-Object System.Drawing.Size(100, 20)
    $dataFolderLabel.Location = New-Object System.Drawing.Point(20, 190)
    $form.Controls.Add($dataFolderLabel)

    $dataFolderTextBox = New-Object System.Windows.Forms.TextBox
    $dataFolderTextBox.Size = New-Object System.Drawing.Size(380, 20)
    $dataFolderTextBox.Location = New-Object System.Drawing.Point(20, 210)
    $dataFolderTextBox.Text = (Get-Location).Path
    $form.Controls.Add($dataFolderTextBox)

    $dataFolderButton = New-Object System.Windows.Forms.Button
    $dataFolderButton.Text = "Browse..."
    $dataFolderButton.Size = New-Object System.Drawing.Size(80, 25)
    $dataFolderButton.Location = New-Object System.Drawing.Point(410, 208)
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
    $excelLabel.Location = New-Object System.Drawing.Point(20, 245)
    $form.Controls.Add($excelLabel)

    $excelTextBox = New-Object System.Windows.Forms.TextBox
    $excelTextBox.Size = New-Object System.Drawing.Size(380, 20)
    $excelTextBox.Location = New-Object System.Drawing.Point(20, 265)
    $excelTextBox.Text = "ExportSpec.xlsx"
    $form.Controls.Add($excelTextBox)

    $excelButton = New-Object System.Windows.Forms.Button
    $excelButton.Text = "Browse..."
    $excelButton.Size = New-Object System.Drawing.Size(80, 25)
    $excelButton.Location = New-Object System.Drawing.Point(410, 263)
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

    # Post-install scripts section (optional)
    $postInstallLabel = New-Object System.Windows.Forms.Label
    $postInstallLabel.Text = "Post-Install Scripts (Optional):"
    $postInstallLabel.Size = New-Object System.Drawing.Size(200, 20)
    $postInstallLabel.Location = New-Object System.Drawing.Point(20, 295)
    $form.Controls.Add($postInstallLabel)

    $postInstallTextBox = New-Object System.Windows.Forms.TextBox
    $postInstallTextBox.Size = New-Object System.Drawing.Size(380, 20)
    $postInstallTextBox.Location = New-Object System.Drawing.Point(20, 315)
    $postInstallTextBox.Text = ""
    $postInstallTextBox.PlaceholderText = "Path to SQL scripts folder or file"
    $form.Controls.Add($postInstallTextBox)

    $postInstallButton = New-Object System.Windows.Forms.Button
    $postInstallButton.Text = "Browse..."
    $postInstallButton.Size = New-Object System.Drawing.Size(80, 25)
    $postInstallButton.Location = New-Object System.Drawing.Point(410, 313)
    $postInstallButton.Add_Click({
        $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderDialog.Description = "Select folder containing post-install SQL scripts"
        $folderDialog.SelectedPath = $dataFolderTextBox.Text
        if ($folderDialog.ShowDialog() -eq "OK") {
            $postInstallTextBox.Text = $folderDialog.SelectedPath
        }
    })
    $form.Controls.Add($postInstallButton)

    # Database connection section
    $dbGroupBox = New-Object System.Windows.Forms.GroupBox
    $dbGroupBox.Text = "Database Connection"
    $dbGroupBox.Size = New-Object System.Drawing.Size(470, 120)
    $dbGroupBox.Location = New-Object System.Drawing.Point(20, 350)
    $form.Controls.Add($dbGroupBox)

    # Server
    $serverLabel = New-Object System.Windows.Forms.Label
    $serverLabel.Text = "SQL Server:"
    $serverLabel.Size = New-Object System.Drawing.Size(80, 20)
    $serverLabel.Location = New-Object System.Drawing.Point(10, 25)
    $dbGroupBox.Controls.Add($serverLabel)

    $serverTextBox = New-Object System.Windows.Forms.TextBox
    $serverTextBox.Size = New-Object System.Drawing.Size(180, 20)
    $serverTextBox.Location = New-Object System.Drawing.Point(95, 23)
    $serverTextBox.Text = "localhost"
    $dbGroupBox.Controls.Add($serverTextBox)

    # Database
    $databaseLabel = New-Object System.Windows.Forms.Label
    $databaseLabel.Text = "Database:"
    $databaseLabel.Size = New-Object System.Drawing.Size(70, 20)
    $databaseLabel.Location = New-Object System.Drawing.Point(285, 25)
    $dbGroupBox.Controls.Add($databaseLabel)

    $databaseTextBox = New-Object System.Windows.Forms.TextBox
    $databaseTextBox.Size = New-Object System.Drawing.Size(120, 20)
    $databaseTextBox.Location = New-Object System.Drawing.Point(340, 23)
    $dbGroupBox.Controls.Add($databaseTextBox)

    # Authentication
    $authLabel = New-Object System.Windows.Forms.Label
    $authLabel.Text = "Authentication:"
    $authLabel.Size = New-Object System.Drawing.Size(85, 20)
    $authLabel.Location = New-Object System.Drawing.Point(10, 55)
    $dbGroupBox.Controls.Add($authLabel)

    $authComboBox = New-Object System.Windows.Forms.ComboBox
    $authComboBox.Size = New-Object System.Drawing.Size(150, 25)
    $authComboBox.Location = New-Object System.Drawing.Point(95, 53)
    $authComboBox.DropDownStyle = "DropDownList"
    $authComboBox.Items.AddRange(@("Windows Authentication", "SQL Server Authentication"))
    $authComboBox.SelectedIndex = 0
    $dbGroupBox.Controls.Add($authComboBox)

    # Username (initially hidden)
    $usernameLabel = New-Object System.Windows.Forms.Label
    $usernameLabel.Text = "Username:"
    $usernameLabel.Size = New-Object System.Drawing.Size(70, 20)
    $usernameLabel.Location = New-Object System.Drawing.Point(10, 85)
    $usernameLabel.Visible = $false
    $dbGroupBox.Controls.Add($usernameLabel)

    $usernameTextBox = New-Object System.Windows.Forms.TextBox
    $usernameTextBox.Size = New-Object System.Drawing.Size(120, 20)
    $usernameTextBox.Location = New-Object System.Drawing.Point(80, 83)
    $usernameTextBox.Visible = $false
    $dbGroupBox.Controls.Add($usernameTextBox)

    # Password (initially hidden)
    $passwordLabel = New-Object System.Windows.Forms.Label
    $passwordLabel.Text = "Password:"
    $passwordLabel.Size = New-Object System.Drawing.Size(70, 20)
    $passwordLabel.Location = New-Object System.Drawing.Point(210, 85)
    $passwordLabel.Visible = $false
    $dbGroupBox.Controls.Add($passwordLabel)

    $passwordTextBox = New-Object System.Windows.Forms.TextBox
    $passwordTextBox.Size = New-Object System.Drawing.Size(120, 20)
    $passwordTextBox.Location = New-Object System.Drawing.Point(280, 83)
    $passwordTextBox.UseSystemPasswordChar = $true
    $passwordTextBox.Visible = $false
    $dbGroupBox.Controls.Add($passwordTextBox)

    # Authentication change handler
    $authComboBox.Add_SelectedIndexChanged({
        $isSqlAuth = $authComboBox.SelectedIndex -eq 1
        $usernameLabel.Visible = $isSqlAuth
        $usernameTextBox.Visible = $isSqlAuth
        $passwordLabel.Visible = $isSqlAuth
        $passwordTextBox.Visible = $isSqlAuth
    })

    # Schema section
    $schemaLabel = New-Object System.Windows.Forms.Label
    $schemaLabel.Text = "Schema Name (optional - defaults to detected prefix):"
    $schemaLabel.Size = New-Object System.Drawing.Size(300, 20)
    $schemaLabel.Location = New-Object System.Drawing.Point(20, 430)
    $form.Controls.Add($schemaLabel)

    $schemaTextBox = New-Object System.Windows.Forms.TextBox
    $schemaTextBox.Size = New-Object System.Drawing.Size(380, 20)
    $schemaTextBox.Location = New-Object System.Drawing.Point(20, 450)
    $schemaTextBox.ForeColor = [System.Drawing.Color]::Gray
    $schemaTextBox.Text = "Leave empty to use detected prefix"
    $form.Controls.Add($schemaTextBox)

    # Add placeholder behavior for schema textbox
    $schemaTextBox.Add_GotFocus({
        if ($schemaTextBox.Text -eq "Leave empty to use detected prefix") {
            $schemaTextBox.Text = ""
            $schemaTextBox.ForeColor = [System.Drawing.Color]::Black
        }
    })
    $schemaTextBox.Add_LostFocus({
        if ([string]::IsNullOrWhiteSpace($schemaTextBox.Text)) {
            $schemaTextBox.Text = "Leave empty to use detected prefix"
            $schemaTextBox.ForeColor = [System.Drawing.Color]::Gray
        }
    })

    # Options section
    $optionsGroupBox = New-Object System.Windows.Forms.GroupBox
    $optionsGroupBox.Text = "Import Options"
    $optionsGroupBox.Size = New-Object System.Drawing.Size(470, 60)
    $optionsGroupBox.Location = New-Object System.Drawing.Point(20, 480)
    $form.Controls.Add($optionsGroupBox)

    # Table exists action
    $tableActionLabel = New-Object System.Windows.Forms.Label
    $tableActionLabel.Text = "If table exists:"
    $tableActionLabel.Size = New-Object System.Drawing.Size(100, 20)
    $tableActionLabel.Location = New-Object System.Drawing.Point(10, 25)
    $optionsGroupBox.Controls.Add($tableActionLabel)

    $tableActionComboBox = New-Object System.Windows.Forms.ComboBox
    $tableActionComboBox.Size = New-Object System.Drawing.Size(120, 25)
    $tableActionComboBox.Location = New-Object System.Drawing.Point(110, 23)
    $tableActionComboBox.DropDownStyle = "DropDownList"
    $tableActionComboBox.Items.AddRange(@("Recreate", "Truncate", "Skip", "Ask"))
    $tableActionComboBox.SelectedIndex = 0
    $optionsGroupBox.Controls.Add($tableActionComboBox)

    # Add tooltip
    $tooltip = New-Object System.Windows.Forms.ToolTip
    $tooltip.SetToolTip($tableActionComboBox, @"
Recreate: Drop and recreate all tables (deletes existing data)
Truncate: Keep tables, clear all data
Skip: Skip tables that already exist
Ask: Prompt for each table (CLI-only, defaults to Recreate in GUI)
"@)

    # Verbose logging checkbox
    $verboseCheckBox = New-Object System.Windows.Forms.CheckBox
    $verboseCheckBox.Text = "Verbose Logging"
    $verboseCheckBox.Size = New-Object System.Drawing.Size(150, 20)
    $verboseCheckBox.Location = New-Object System.Drawing.Point(245, 25)
    $verboseCheckBox.Checked = $false
    $optionsGroupBox.Controls.Add($verboseCheckBox)

    $tooltip.SetToolTip($verboseCheckBox, "Show detailed operational information during import")

    # Progress section
    $progressLabel = New-Object System.Windows.Forms.Label
    $progressLabel.Text = "Ready to import..."
    $progressLabel.Size = New-Object System.Drawing.Size(470, 20)
    $progressLabel.Location = New-Object System.Drawing.Point(20, 550)
    $form.Controls.Add($progressLabel)

    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Size = New-Object System.Drawing.Size(470, 23)
    $progressBar.Location = New-Object System.Drawing.Point(20, 575)
    $progressBar.Style = "Marquee"
    $progressBar.MarqueeAnimationSpeed = 0
    $form.Controls.Add($progressBar)

    # Output text box
    $outputTextBox = New-Object System.Windows.Forms.TextBox
    $outputTextBox.Multiline = $true
    $outputTextBox.ScrollBars = "Vertical"
    $outputTextBox.Size = New-Object System.Drawing.Size(470, 80)
    $outputTextBox.Location = New-Object System.Drawing.Point(20, 605)
    $outputTextBox.ReadOnly = $true
    $outputTextBox.BackColor = [System.Drawing.Color]::Black
    $outputTextBox.ForeColor = [System.Drawing.Color]::Lime
    $outputTextBox.Font = New-Object System.Drawing.Font("Consolas", 8)
    $form.Controls.Add($outputTextBox)

    # Buttons
    $startButton = New-Object System.Windows.Forms.Button
    $startButton.Text = "Start Import"
    $startButton.Size = New-Object System.Drawing.Size(100, 30)
    $startButton.Location = New-Object System.Drawing.Point(500, 605)
    $startButton.BackColor = [System.Drawing.Color]::LightGreen
    $startButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($startButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Size = New-Object System.Drawing.Size(100, 30)
    $cancelButton.Location = New-Object System.Drawing.Point(500, 645)
    $cancelButton.Enabled = $false
    $form.Controls.Add($cancelButton)

    $exitButton = New-Object System.Windows.Forms.Button
    $exitButton.Text = "Exit"
    $exitButton.Size = New-Object System.Drawing.Size(100, 30)
    $exitButton.Location = New-Object System.Drawing.Point(500, 685)
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

        # Validate database connection fields
        if ([string]::IsNullOrWhiteSpace($serverTextBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Please enter a SQL Server instance name.", "Error", "OK", "Error")
            return
        }

        if ([string]::IsNullOrWhiteSpace($databaseTextBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Please enter a database name.", "Error", "OK", "Error")
            return
        }

        if ($authComboBox.SelectedIndex -eq 1) {
            if ([string]::IsNullOrWhiteSpace($usernameTextBox.Text)) {
                [System.Windows.Forms.MessageBox]::Show("Please enter a username for SQL Server authentication.", "Error", "OK", "Error")
                return
            }
            if ([string]::IsNullOrWhiteSpace($passwordTextBox.Text)) {
                [System.Windows.Forms.MessageBox]::Show("Please enter a password for SQL Server authentication.", "Error", "OK", "Error")
                return
            }
        }

        # Show confirmation of optimized assumptions
        $confirmResult = [System.Windows.Forms.MessageBox]::Show(@"
OPTIMIZED IMPORT ASSUMPTIONS:
• Every data file MUST have ImportID as first field
• Field count MUST match exactly (ImportID + spec fields)
• Multi-line fields with embedded newlines are fully supported
• Only SqlBulkCopy (no INSERT fallback)
• No file logging for maximum speed

Do you want to continue with these assumptions?
"@, "Confirm Optimized Import", "YesNo", "Question")

        if ($confirmResult -eq "No") {
            return
        }

        # Disable start button and enable cancel
        $startButton.Enabled = $false
        $cancelButton.Enabled = $true
        $progressBar.MarqueeAnimationSpeed = 30
        $progressLabel.Text = "Import in progress..."
        $outputTextBox.AppendText("Starting import process...`r`n")

        # Create a background runspace to execute the import
        $global:ImportRunspace = [runspacefactory]::CreateRunspace()
        $global:ImportRunspace.Open()

        # Determine schema name (handle placeholder text)
        $schemaName = if ([string]::IsNullOrWhiteSpace($schemaTextBox.Text) -or $schemaTextBox.Text -eq "Leave empty to use detected prefix") { $null } else { $schemaTextBox.Text.Trim() }

        # Map GUI selections to module parameters
        $tableAction = switch ($tableActionComboBox.SelectedIndex) {
            0 { "Recreate" }
            1 { "Truncate" }
            2 { "Skip" }
            3 { "Recreate" }  # Ask not supported in GUI runspace, use Recreate
            default { "Recreate" }
        }

        $global:ImportRunspace.SessionStateProxy.SetVariable("DataFolder", $dataFolderTextBox.Text)
        $global:ImportRunspace.SessionStateProxy.SetVariable("ExcelSpecFile", $excelTextBox.Text)
        $global:ImportRunspace.SessionStateProxy.SetVariable("Server", $serverTextBox.Text)
        $global:ImportRunspace.SessionStateProxy.SetVariable("Database", $databaseTextBox.Text)
        $global:ImportRunspace.SessionStateProxy.SetVariable("Username", $usernameTextBox.Text)
        $global:ImportRunspace.SessionStateProxy.SetVariable("Password", $passwordTextBox.Text)
        $global:ImportRunspace.SessionStateProxy.SetVariable("SchemaName", $schemaName)
        $global:ImportRunspace.SessionStateProxy.SetVariable("TableAction", $tableAction)
        $global:ImportRunspace.SessionStateProxy.SetVariable("PostInstallScripts", $postInstallTextBox.Text)
        # Set VerbosePreference in the runspace if verbose logging is enabled
        if ($verboseCheckBox.Checked) {
            $global:ImportRunspace.SessionStateProxy.SetVariable("VerbosePreference", "Continue")
        } else {
            $global:ImportRunspace.SessionStateProxy.SetVariable("VerbosePreference", "SilentlyContinue")
        }
        $global:ImportRunspace.SessionStateProxy.SetVariable("ModulePath", $coreModulePath)

        $global:ImportPowerShell = [powershell]::Create()
        $global:ImportPowerShell.Runspace = $global:ImportRunspace

        # Import script to run in background
        $importScript = {
            try {
                Import-Module $ModulePath -Force

                # Execute the import
                $importParams = @{
                    DataFolder = $DataFolder
                    ExcelSpecFile = $ExcelSpecFile
                    Server = $Server
                    Database = $Database
                    SchemaName = $SchemaName
                    TableExistsAction = $TableAction
                }

                # Add Username/Password if provided (SQL Server authentication)
                if (-not [string]::IsNullOrWhiteSpace($Username)) {
                    $importParams.Username = $Username
                    $importParams.Password = $Password
                }

                # Add PostInstallScripts if provided
                if (-not [string]::IsNullOrWhiteSpace($PostInstallScripts)) {
                    $importParams.PostInstallScripts = $PostInstallScripts
                }

                # Add Verbose flag if enabled (VerbosePreference is set in runspace)
                if ($VerbosePreference -eq 'Continue') {
                    $importParams.Verbose = $true
                }

                $result = Invoke-SqlServerDataImport @importParams

                return @{
                    Success = $true
                    Message = "Import completed successfully"
                    Summary = $result
                }
            }
            catch {
                return @{
                    Success = $false
                    Message = $_.Exception.Message
                    Error = $_
                }
            }
        }

        $global:ImportPowerShell.AddScript($importScript)
        $asyncResult = $global:ImportPowerShell.BeginInvoke()

        # Start a timer to check for completion
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 1000
        $timer.Add_Tick({
            if ($asyncResult.IsCompleted) {
                $timer.Stop()
                $progressBar.MarqueeAnimationSpeed = 0
                $startButton.Enabled = $true
                $cancelButton.Enabled = $false

                try {
                    $result = $global:ImportPowerShell.EndInvoke($asyncResult)

                    if ($result.Success) {
                        $progressLabel.Text = "Import completed successfully!"
                        $progressLabel.ForegroundColor = [System.Drawing.Color]::Green
                        $outputTextBox.AppendText("Import completed successfully!`r`n")
                        $outputTextBox.AppendText("$($result.Summary.Count) tables processed.`r`n")
                    } else {
                        $progressLabel.Text = "Import failed. Check output for details."
                        $progressLabel.ForegroundColor = [System.Drawing.Color]::Red
                        $outputTextBox.AppendText("Import failed: $($result.Message)`r`n")
                        $outputTextBox.AppendText("Common causes: Field count mismatch, missing ImportID, data type issues`r`n")
                    }
                }
                catch {
                    $progressLabel.Text = "Import failed with error."
                    $progressLabel.ForegroundColor = [System.Drawing.Color]::Red
                    $outputTextBox.AppendText("Import failed: $($_.Exception.Message)`r`n")
                }

                # Clean up
                if ($global:ImportPowerShell) {
                    $global:ImportPowerShell.Dispose()
                    $global:ImportPowerShell = $null
                }
                if ($global:ImportRunspace) {
                    $global:ImportRunspace.Close()
                    $global:ImportRunspace.Dispose()
                    $global:ImportRunspace = $null
                }
            }
        })
        $timer.Start()
    })

    $cancelButton.Add_Click({
        if ($global:ImportPowerShell -and $global:ImportRunspace) {
            $result = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to cancel the import?", "Confirm Cancel", "YesNo", "Question")
            if ($result -eq "Yes") {
                try {
                    $global:ImportPowerShell.Stop()
                    $global:ImportRunspace.Close()
                }
                catch { }

                $progressBar.MarqueeAnimationSpeed = 0
                $progressLabel.Text = "Import cancelled by user."
                $progressLabel.ForegroundColor = [System.Drawing.Color]::Orange
                $startButton.Enabled = $true
                $cancelButton.Enabled = $false
                $outputTextBox.AppendText("Import cancelled by user.`r`n")
            }
        }
    })

    # Show the form
    $form.ShowDialog()
}

# Show the GUI
Show-ImportGUI
