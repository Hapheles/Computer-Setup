# System Settings Module
function Initialize-SettingsTab {
    param(
        [System.Windows.Window]$Window,
        [string]$SettingsPath
    )
    
    # Store window reference globally
    $global:MainWindow = $Window
    
    Write-Host "Initializing System Settings Tab" -ForegroundColor Green
    
    try {
        # Initialize quick actions
        Initialize-QuickActions -Window $Window
        
        # Initialize tweaks panel if config exists
        if ($SettingsPath -and (Test-Path $SettingsPath)) {
            Initialize-TweaksPanel -SettingsPath $SettingsPath
        } else {
            Write-Host "No system settings config found, skipping tweaks panel" -ForegroundColor Yellow
        }
        
        Write-Host "System settings tab initialized successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "Error in Initialize-SettingsTab: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Initialize-QuickActions {
    param([System.Windows.Window]$Window)
    
    Write-Host "Initializing Quick Actions" -ForegroundColor Yellow
    
    try {
        $buttonFlushDNS = $Window.FindName("ButtonFlushDNS")
        $buttonResetWinsock = $Window.FindName("ButtonResetWinsock")
        $buttonNetworkReset = $Window.FindName("ButtonNetworkReset")
        $buttonIPV6Reset = $Window.FindName("ButtonIPV6Reset")
        $buttonEventViewerRegistryPermissions = $Window.FindName("ButtonEventViewerRegistryPermissions")
        $buttonHighPerformance = $window.FindName("ButtonHighPerformance")
        $buttonTurnOffSleep = $window.FindName("ButtonTurnOffSleep")
        $buttonDisableHardDiskTimeout = $window.FindName("DisableHardDiskTimeout")
        $buttonInstallMSMQComponents = $window.FindName("InstallMSMQComponents")
        
        if ($buttonFlushDNS) {
            $buttonFlushDNS.Add_Click({ 
                Write-Host "Flushing DNS..." -ForegroundColor Cyan
                Invoke-FlushDNS 
            })
        }
        
        if ($buttonResetWinsock) {
            $buttonResetWinsock.Add_Click({ 
                Write-Host "Resetting Winsock..." -ForegroundColor Cyan
                Invoke-ResetWinsock 
            })
        }
        
        if ($buttonNetworkReset) {
            $buttonNetworkReset.Add_Click({ 
                Write-Host "Resetting Network..." -ForegroundColor Cyan
                Invoke-NetworkReset 
            })
        }
        
        if ($buttonIPV6Reset) {
            $buttonIPV6Reset.Add_Click({ 
                Write-Host "Disabling IPv6..." -ForegroundColor Cyan
                Invoke-IPV6Reset 
            })
        }

        if ($buttonEventViewerRegistryPermissions) {
            $buttonEventViewerRegistryPermissions.Add_Click({
                Write-Host "Granting Everyone access to EventLog Security registry..." -ForegroundColor Cyan
                Invoke-EventViewerRegistryPermission
            })
        }

        if ($buttonHighPerformance) {
            $buttonHighPerformance.Add_Click({
                Write-Host "Changing Power Plan to High Performance..." -ForegroundColor Cyan
                Invoke-HighPerformance
            })
        }

        if ($buttonTurnOffSleep) {
            $buttonTurnOffSleep.Add_Click({
                Write-Host "Disabling Sleep Mode..." -ForegroundColor Cyan
                Invoke-TurnOffSleep
            })
        }

        if ($buttonDisableHardDiskTimeout) {
            $buttonDisableHardDiskTimeout.Add_Click({
                Write-Host "Disabling Hard Disk Timeout..." -ForegroundColor Cyan
                Invoke-SetHardDiskNeverOff
            })
        }

        if ($buttonInstallMSMQComponents) {
            $buttonInstallMSMQComponents.Add_Click({
                Write-Host "Installing MSMQ Components..." -ForegroundColor Cyan
                Invoke-InstallMSMQ
            })
        }
        
        Write-Host "Quick actions initialized" -ForegroundColor Green
    }
    catch {
        Write-Host "Error in Initialize-QuickActions: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Initialize-TweaksPanel {
    param(
        [string]$SettingsPath
    )
    
    Write-Host "Initializing Tweaks Panel" -ForegroundColor Yellow
    
    try {
        $tweaksPanel = $global:MainWindow.FindName("TweaksPanel")
        $buttonApplyTweaks = $global:MainWindow.FindName("ButtonApplyTweaks")
        $buttonResetSettings = $global:MainWindow.FindName("ButtonResetSettings")
        
        if (-not $tweaksPanel) {
            Write-Host "TweaksPanel not found in XAML" -ForegroundColor Yellow
            return
        }
        
        # Clear panel
        $tweaksPanel.Children.Clear()
        
        # Load config
        $tweaks = Get-SystemTweaksConfig -Path $SettingsPath
        
        if ($tweaks.Count -eq 0) {
            $textBlock = New-Object System.Windows.Controls.TextBlock
            $textBlock.Text = "No tweaks configured"
            $textBlock.Foreground = [System.Windows.Media.Brushes]::Gray
            $textBlock.Margin = New-Object System.Windows.Thickness(10)
            $tweaksPanel.Children.Add($textBlock)
            return
        }
        
        # Add tweaks to panel
        foreach ($tweak in $tweaks) {
            $checkBox = New-Object System.Windows.Controls.CheckBox
            $checkBox.Content = $tweak.name
            $checkBox.ToolTip = $tweak.description
            $checkBox.Margin = New-Object System.Windows.Thickness(5)
            $checkBox.Tag = $tweak
            
            if ($tweak.dangerous) {
                $checkBox.Foreground = [System.Windows.Media.Brushes]::DarkRed
                $checkBox.FontWeight = [System.Windows.FontWeights]::Bold
            }
            
            $tweaksPanel.Children.Add($checkBox)
        }
        
        if ($buttonApplyTweaks) {
            $buttonApplyTweaks.Add_Click({
                Submit-SelectedTweaks
            })
        }
        
        if ($buttonResetSettings) {
            $buttonResetSettings.Add_Click({
                Reset-TweaksSelection
            })
        }
        
        Write-Host "Tweaks panel initialized with $($tweaks.Count) tweaks" -ForegroundColor Green
    }
    catch {
        Write-Host "Error in Initialize-TweaksPanel: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Get-SystemTweaksConfig {
    param([string]$Path)
    
    Write-Host "Loading system tweaks from: $Path" -ForegroundColor Gray
    
    if (-not (Test-Path $Path)) {
        Write-Host "Config file not found: $Path" -ForegroundColor Yellow
        return @()
    }
    
    try {
        $jsonContent = Get-Content -Path $Path -Raw | ConvertFrom-Json
        return $jsonContent.systemTweaks
    }
    catch {
        Write-Host "Error reading config: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

function Invoke-SystemTweak {
    param(
        [PSCustomObject]$Tweak
    )
    
    try {
        # Update progress
        if ($global:MainWindow -and $global:MainWindow.FindName("ProgressText")) {
            $progressText = $global:MainWindow.FindName("ProgressText")
            $global:MainWindow.Dispatcher.Invoke([action]{
                $progressText.Text = "Applying: $($Tweak.name)"
            }, [System.Windows.Threading.DispatcherPriority]::Normal)
        } else {
            Write-Host "Applying: $($Tweak.name)" -ForegroundColor Yellow
        }

        # Get project root using multiple reliable methods
        $projectRoot = $null
        
        # Method 1: Use PSScriptRoot (most reliable for modules)
        if ($PSScriptRoot) {
            $projectRoot = Split-Path $PSScriptRoot -Parent
            Write-Host "  Using PSScriptRoot method: $projectRoot" -ForegroundColor Gray
        }
        
        # Method 2: Use current directory as fallback
        if (-not $projectRoot -or -not (Test-Path $projectRoot)) {
            $projectRoot = Get-Location
            Write-Host "  Using current directory method: $projectRoot" -ForegroundColor Gray
        }
        
        # Method 3: Try to find the project root by looking for known directories
        if (-not $projectRoot -or -not (Test-Path $projectRoot)) {
            $currentDir = Get-Location
            if (Test-Path (Join-Path $currentDir "Scripts")) {
                $projectRoot = $currentDir
            } elseif (Test-Path (Join-Path (Split-Path $currentDir -Parent) "Scripts")) {
                $projectRoot = Split-Path $currentDir -Parent
            }
            Write-Host "  Using directory search method: $projectRoot" -ForegroundColor Gray
        }
        
        Write-Host "  Final project root: $projectRoot" -ForegroundColor Gray
        
        if ($Tweak.scriptFile) {
            # Execute from script file
            $scriptFilePath = Join-Path $projectRoot $Tweak.scriptFile
            Write-Host "  Script file: $scriptFilePath" -ForegroundColor Gray
            
            if (Test-Path $scriptFilePath) {
                Write-Host "  Executing script..." -ForegroundColor Gray
                
                # Capture output from the script
                $scriptOutput = & $scriptFilePath 2>&1
                
                # Check if script executed successfully
                if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) {
                    Write-Host "  Script executed successfully" -ForegroundColor Green
                    if ($scriptOutput) {
                        Write-Host "  Output: $scriptOutput" -ForegroundColor Gray
                    }
                    return $true
                } else {
                    Write-Host "  Script completed with exit code: $LASTEXITCODE" -ForegroundColor Yellow
                    return $true
                }
            } else {
                Write-Host "  Script file not found: $scriptFilePath" -ForegroundColor Red
                Write-Host "  Available scripts in Scripts directory:" -ForegroundColor Gray
                $scriptsDir = Join-Path $projectRoot "Scripts"
                if (Test-Path $scriptsDir) {
                    Get-ChildItem $scriptsDir -Filter "*.ps1" | ForEach-Object {
                        Write-Host "    - $($_.Name)" -ForegroundColor Gray
                    }
                }
                return $false
            }
            
        } elseif ($Tweak.script) {
            # Execute inline script
            Write-Host "  Executing inline script..." -ForegroundColor Gray
            Write-Host "  Script: $($Tweak.script)" -ForegroundColor Gray
            
            try {
                Invoke-Expression $Tweak.script
                Write-Host "  Inline script executed successfully" -ForegroundColor Green
                return $true
            }
            catch {
                Write-Host "  Inline script failed: $($_.Exception.Message)" -ForegroundColor Red
                return $false
            }
            
        } else {
            Write-Host "  No script or scriptFile specified for tweak: $($Tweak.name)" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "  Unexpected error in Invoke-SystemTweak: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        return $false
    }
}

function Submit-SelectedTweaks {
    Write-Host "=== Apply Selected Tweaks Started ===" -ForegroundColor Cyan
    
    try {
        # Debug check if TweaksPanel exists
        $tweaksPanel = $global:MainWindow.FindName("TweaksPanel")
        if (-not $tweaksPanel) {
            Write-Host " ERROR: TweaksPanel not found in window!" -ForegroundColor Red
            [System.Windows.MessageBox]::Show("Tweaks panel not found. Please check the UI layout.", "Error", "OK", "Error") | Out-Null
            return
        }
        
        Write-Host "TweaksPanel found" -ForegroundColor Green
        
        # Get all checkboxes from the panel
        $checkboxes = $tweaksPanel.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] }
        Write-Host "Found $($checkboxes.Count) checkboxes in TweaksPanel" -ForegroundColor Gray
        
        # Get selected tweaks
        $selectedTweaks = $checkboxes | Where-Object { $_.IsChecked -eq $true -and $null -ne $_.Tag }
        Write-Host "Selected $($selectedTweaks.Count) tweaks to apply" -ForegroundColor Gray
        
        if ($selectedTweaks.Count -eq 0) {
            Write-Host "No tweaks selected" -ForegroundColor Yellow
            [System.Windows.MessageBox]::Show("No tweaks selected. Please select at least one tweak to apply.", "Info", "OK", "Information") | Out-Null
            return
        }
        
        # Show confirmation for dangerous operations
        $dangerousTweaks = $selectedTweaks | Where-Object { $_.Tag.dangerous -eq $true }
        if ($dangerousTweaks.Count -gt 0) {
            $dangerousNames = ($dangerousTweaks | ForEach-Object { $_.Tag.name }) -join "`n• "
            $result = [System.Windows.MessageBox]::Show(
                "The following operations are potentially dangerous:`n`n• $dangerousNames`n`nAre you sure you want to continue?",
                "Warning - Dangerous Operations",
                "YesNo",
                "Warning"
            )
            if ($result -ne "Yes") {
                Write-Host "User cancelled dangerous operations" -ForegroundColor Yellow
                return
            }
        }
        
        # Execute selected tweaks
        $successCount = 0
        $totalCount = $selectedTweaks.Count
        
        Write-Host "Starting to apply $totalCount tweaks..." -ForegroundColor Yellow
        
        foreach ($checkBox in $selectedTweaks) {
            $tweak = $checkBox.Tag
            Write-Host "`nApplying: $($tweak.name)" -ForegroundColor Cyan
            Write-Host "  Description: $($tweak.description)" -ForegroundColor Gray
            
            $success = Invoke-SystemTweak -Tweak $tweak
            if ($success) {
                $successCount++
                Write-Host "  Successfully applied" -ForegroundColor Green
            } else {
                Write-Host "  Failed to apply" -ForegroundColor Red
            }
        }
        
        # Show final results
        Write-Host "`n=== Application Results ===" -ForegroundColor Cyan
        Write-Host "Successfully applied: $successCount of $totalCount tweaks" -ForegroundColor $(if ($successCount -eq $totalCount) { 'Green' } else { 'Yellow' })
        
        if ($successCount -eq $totalCount) {
            [System.Windows.MessageBox]::Show(
                "All $successCount tweaks were applied successfully!",
                "Success",
                "OK",
                "Information"
            ) | Out-Null
        } else {
            [System.Windows.MessageBox]::Show(
                "Applied $successCount of $totalCount tweaks. Some operations may have failed. Check the console for details.",
                "Completed",
                "OK",
                "Information"
            ) | Out-Null
        }
        
    }
    catch {
        Write-Host " ERROR in Apply-SelectedTweaks: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack trace: $($_.Exception.StackTrace)" -ForegroundColor Red
        
        [System.Windows.MessageBox]::Show(
            "Error applying tweaks: $($_.Exception.Message)`n`nCheck the console for more details.",
            "Error",
            "OK",
            "Error"
        ) | Out-Null
    }
    
    Write-Host "=== Apply Selected Tweaks Completed ===" -ForegroundColor Cyan
}

function Reset-TweaksSelection {
    try {
        $tweaksPanel = $global:MainWindow.FindName("TweaksPanel")
        foreach ($child in $tweaksPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox]) {
                $child.IsChecked = $false
            }
        }
        Write-Host "Tweaks selection reset" -ForegroundColor Green
    }
    catch {
        Write-Host "Error resetting selection: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-FlushDNS {
    try {
        Start-Process -FilePath "ipconfig" -ArgumentList "/flushdns" -Wait -NoNewWindow
        [System.Windows.MessageBox]::Show("DNS cache flushed", "Success", "OK", "Information")
        Write-Host "DNS flushed successfully" -ForegroundColor Green
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to flush DNS", "Error", "OK", "Error")
    }
}

function Invoke-ResetWinsock {
    try {
        Start-Process -FilePath "netsh" -ArgumentList "winsock reset" -Wait -NoNewWindow -Verb RunAs
        [System.Windows.MessageBox]::Show("Winsock reset - reboot required", "Success", "OK", "Information")
        Write-Host "Winsock reset successfully" -ForegroundColor Green
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to reset Winsock", "Error", "OK", "Error")
    }
}

function Invoke-NetworkReset {
    try {
        Start-Process -FilePath "netsh" -ArgumentList "int ip reset" -Wait -NoNewWindow -Verb RunAs
        [System.Windows.MessageBox]::Show("Network reset - reboot recommended", "Success", "OK", "Information")
        Write-Host "Network reset successfully" -ForegroundColor Green
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to reset network", "Error", "OK", "Error")
    }
}

function Invoke-IPV6Reset {
    try {
        Get-NetAdapter | Disable-NetAdapterBinding -ComponentID ms_tcpip6
        [System.Windows.MessageBox]::Show("IPv6 disabled on all adapters", "Success", "OK", "Information")
        Write-Host "IPv6 disabled successfully" -ForegroundColor Green
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to disable IPv6", "Error", "OK", "Error")
    }
}

function Invoke-EventViewerRegistryPermission {
    try {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Security"
        
        # Check if path exists
        if (-not (Test-Path $registryPath)) {
            Write-Host "Registry path not found: $registryPath" -ForegroundColor Red
            return $false
        }
        
        # Get current ACL
        $acl = Get-Acl $registryPath
        
        # Create new rule for Everyone with Full Control
        $everyoneRule = New-Object System.Security.AccessControl.RegistryAccessRule(
            "Everyone", 
            "FullControl", 
            "ContainerInherit,ObjectInherit", 
            "None", 
            "Allow"
        )
        
        # Add the rule to the ACL
        $acl.SetAccessRule($everyoneRule)
        
        # Apply the modified ACL
        Set-Acl -Path $registryPath -AclObject $acl
        Write-Host "Everyone group granted Full Control to EventLog Security registry" -ForegroundColor Green
    }
    catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        [System.Windows.MessageBox]::Show("Failed to enable access permissions", "Error", "OK", "Error")
    }
}

function Invoke-HighPerformance {
    try {
        powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
        Write-Host "Power Options changed to High Performance Mode" -ForegroundColor Green

    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to change power options to High Performance Mode", "Error", "OK", "Error")
    }
}

function Invoke-TurnOffSleep {
    try {
        # Disable sleep on battery power
        & powercfg -change -standby-timeout-ac 0       
        # Disable sleep on DC power (battery)
        & powercfg -change -standby-timeout-dc 0   
        # Disable hibernate
        & powercfg -h off
        Write-Host "Sleep Mode disabled successfully" -ForegroundColor Green
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to disable sleep mode", "Error", "OK", "Error")
    }
}

function Invoke-SetHardDiskNeverOff {
    try {
        & powercfg -change -disk-timeout-ac 0
        & powercfg -change -disk-timeout-dc 0    
        Write-Host "Hard Disk timeout disabled." -ForegroundColor Green
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to disable Hard Disk timeout", "Error", "OK", "Error")
    }
}

function Invoke-InstallMSMQ {
    try {
        # Minimal installation - just the essentials
        & dism /online /enable-feature /featurename:MSMQ-Server /all /norestart
        & dism /online /enable-feature /featurename:MSMQ-ServerCore /all /norestart
        Write-Host "MSMQ core components installed." -ForegroundColor Green
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to install MSMQ core components", "Error", "OK", "Error")
    }
}

# Export only the main function
Export-ModuleMember -Function Initialize-SettingsTab