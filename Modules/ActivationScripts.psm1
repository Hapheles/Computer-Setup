# Handles Windows and Microsoft activation scripts
function Initialize-ActivationTab {
    param(
        [System.Windows.Window]$Window,
        [string]$ScriptsPath
    )
    
    Write-Host "Initializing Activation Tab" -ForegroundColor Green
    
    try {
        # Store window reference globally
        $global:MainWindow = $Window
        
        # Load activation scripts configuration
        $activationScripts = Get-ActivationScriptsConfig -Path $ScriptsPath
        
        # Initialize the activation panel
        Initialize-ActivationPanel -Scripts $activationScripts
        
        Write-Host "Activation tab initialized successfully with $($activationScripts.Count) scripts" -ForegroundColor Green
    }
    catch {
        Write-Host "Error in Initialize-ActivationTab: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Get-ActivationScriptsConfig {
    param([string]$Path)
    
    Write-Host "Loading activation scripts from: $Path" -ForegroundColor Gray
    
    if (-not (Test-Path $Path)) {
        Write-Host "Activation config file not found: $Path" -ForegroundColor Yellow
        return @()
    }
    
    try {
        $jsonContent = Get-Content -Path $Path -Raw | ConvertFrom-Json
        return $jsonContent.Scripts
    }
    catch {
        Write-Host "Error reading activation config: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

function Initialize-ActivationPanel {
    param([array]$Scripts)
    
    Write-Host "Initializing Activation Panel" -ForegroundColor Yellow
    
    try {
        $activationPanel = $global:MainWindow.FindName("ActivationPanel")
        $buttonRunActivation = $global:MainWindow.FindName("ButtonRunActivation")
        
        if (-not $activationPanel) {
            Write-Host "ActivationPanel not found in XAML" -ForegroundColor Yellow
            return
        }
        
        # Clear panel
        $activationPanel.Children.Clear()
        
        if ($Scripts.Count -eq 0) {
            $textBlock = New-Object System.Windows.Controls.TextBlock
            $textBlock.Text = "No activation scripts configured"
            $textBlock.Foreground = [System.Windows.Media.Brushes]::Gray
            $textBlock.Margin = New-Object System.Windows.Thickness(10)
            $activationPanel.Children.Add($textBlock)
            return
        }
        
        # Create radio buttons for script selection
        $scriptGroup = New-Object System.Windows.Controls.StackPanel
        $scriptGroup.Margin = New-Object System.Windows.Thickness(10)
        
        # Add title
        $titleText = New-Object System.Windows.Controls.TextBlock
        $titleText.Text = "Select Activation Method:"
        $titleText.FontWeight = [System.Windows.FontWeights]::Bold
        $titleText.Margin = New-Object System.Windows.Thickness(0,0,0,10)
        $scriptGroup.Children.Add($titleText)
        
        # Create radio buttons for each script
        foreach ($script in $Scripts) {
            $radioButton = New-Object System.Windows.Controls.RadioButton
            $radioButton.Content = $script.name
            $radioButton.ToolTip = $script.description
            $radioButton.Margin = New-Object System.Windows.Thickness(0,5,0,5)
            $radioButton.Tag = $script
            $radioButton.GroupName = "ActivationScripts"
            
            $scriptGroup.Children.Add($radioButton)
        }
        
        $activationPanel.Children.Add($scriptGroup)
        
        # Set up run button
        if ($buttonRunActivation) {
            $buttonRunActivation.Add_Click({
                Invoke-SelectedActivationScript
            })
        }
        
        Write-Host "Activation panel initialized with $($Scripts.Count) scripts" -ForegroundColor Green
    }
    catch {
        Write-Host "Error in Initialize-ActivationPanel: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-SelectedActivationScript {
    Write-Host "=== Running Activation Script ===" -ForegroundColor Cyan
    
    try {
        $activationPanel = $global:MainWindow.FindName("ActivationPanel")
        if (-not $activationPanel) {
            Write-Host "ERROR: ActivationPanel not found!" -ForegroundColor Red
            return
        }
        
        # Find the selected radio button
        $selectedScript = $null
        foreach ($child in $activationPanel.Children) {
            if ($child -is [System.Windows.Controls.StackPanel]) {
                foreach ($radioButton in $child.Children) {
                    if ($radioButton -is [System.Windows.Controls.RadioButton] -and $radioButton.IsChecked -eq $true) {
                        $selectedScript = $radioButton.Tag
                        break
                    }
                }
            }
        }
        
        if (-not $selectedScript) {
            Write-Host "No activation method selected. Please select an option." -ForegroundColor Yellow
            [System.Windows.MessageBox]::Show("Please select an activation method first.", "Selection Required", "OK", "Information") | Out-Null
            return
        }
        
        Write-Host "Selected: $($selectedScript.name)" -ForegroundColor Cyan
        Write-Host "Description: $($selectedScript.description)" -ForegroundColor Gray
        
        # Show confirmation dialog for activation scripts
        $result = [System.Windows.MessageBox]::Show(
            "You are about to run: $($selectedScript.name)`n`n$($selectedScript.description)`n`nDo you want to continue?",
            "Confirm Activation",
            "YesNo",
            "Question"
        )
        
        if ($result -ne "Yes") {
            Write-Host "Activation cancelled by user" -ForegroundColor Yellow
            return
        }
        
        # Update progress
        if ($global:MainWindow -and $global:MainWindow.FindName("ProgressText")) {
            $progressText = $global:MainWindow.FindName("ProgressText")
            $global:MainWindow.Dispatcher.Invoke([action]{
                $progressText.Text = "Running: $($selectedScript.name)"
            })
        }
        
        Write-Host "Executing activation command..." -ForegroundColor Yellow
        
        # Execute the activation command
        $success = Invoke-ActivationCommand -CommandLine $selectedScript.cmdline -ScriptName $selectedScript.name
        
        if ($success) {
            Write-Host "Activation script completed successfully" -ForegroundColor Green
            [System.Windows.MessageBox]::Show(
                "Activation script completed. Please check the console for details.",
                "Activation Complete",
                "OK",
                "Information"
            ) | Out-Null
        } else {
            Write-Host "Activation script encountered issues" -ForegroundColor Red
            [System.Windows.MessageBox]::Show(
                "Activation script completed with issues. Check the console for details.",
                "Activation Completed",
                "OK",
                "Warning"
            ) | Out-Null
        }
        
    }
    catch {
        Write-Host "ERROR in Invoke-SelectedActivationScript: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack trace: $($_.Exception.StackTrace)" -ForegroundColor Red
        
        [System.Windows.MessageBox]::Show(
            "Error running activation script: $($_.Exception.Message)",
            "Error",
            "OK",
            "Error"
        ) | Out-Null
    }
    
    Write-Host "=== Activation Script Execution Completed ===" -ForegroundColor Cyan
}

function Invoke-ActivationCommand {
    param(
        [string]$CommandLine,
        [string]$ScriptName
    )
    
    try {
        Write-Host "Command: $CommandLine" -ForegroundColor Gray
        
        # Execute the command based on type
        if ($CommandLine -match "\.cmd$|\.bat$") {
            # For batch files
            Write-Host "Executing batch file..." -ForegroundColor Gray
            & cmd.exe /c $CommandLine
        } elseif ($CommandLine -match "^iex\s|^irm\s|Invoke-Expression|Invoke-RestMethod") {
            # For PowerShell commands
            Write-Host "Executing PowerShell command..." -ForegroundColor Gray
            Invoke-Expression $CommandLine
        } else {
            # Generic command execution
            Write-Host "Executing command..." -ForegroundColor Gray
            Invoke-Expression $CommandLine
        }
        
        Write-Host "Command execution completed" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error executing activation command: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Get-ActivationScriptByName {
    param([string]$Name)
    
    try {
        $activationPanel = $global:MainWindow.FindName("ActivationPanel")
        if ($activationPanel) {
            foreach ($child in $activationPanel.Children) {
                if ($child -is [System.Windows.Controls.StackPanel]) {
                    foreach ($radioButton in $child.Children) {
                        if ($radioButton -is [System.Windows.Controls.RadioButton] -and $radioButton.Content -eq $Name) {
                            return $radioButton.Tag
                        }
                    }
                }
            }
        }
        return $null
    }
    catch {
        Write-Host "Error finding activation script: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Export the main function
Export-ModuleMember -Function Initialize-ActivationTab