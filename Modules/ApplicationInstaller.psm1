# Application Installer Module
function Get-SoftwareConfig {
    param([string]$Path)
    
    Write-Host "[Get-SoftwareConfig] Loading from: $Path" -ForegroundColor Gray
    
    if (-not (Test-Path $Path)) {
        throw "Configuration file not found: $Path"
    }
    
    try {
        $jsonContent = Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-Host "[Get-SoftwareConfig] Loaded $($jsonContent.software.Count) items" -ForegroundColor Green
        return $jsonContent.software
    }
    catch {
        throw "Error reading JSON configuration: $($_.Exception.Message)"
    }
}

function Initialize-SoftwareTab {
    param(
        [System.Windows.Window]$Window,
        [string]$ConfigPath
    )
    
    Write-Host "[Initialize-SoftwareTab] Starting..." -ForegroundColor Gray
    
    try {
        # Get controls with null checks
        $softwarePanel = $Window.FindName("SoftwarePanel")
        $progressText = $Window.FindName("ProgressText")
        $progressBar = $Window.FindName("ProgressBar")
        $buttonInstallAll = $Window.FindName("ButtonInstallAll")
        $buttonRefreshSoftware = $Window.FindName("ButtonRefreshSoftware")
        
        Write-Host "[Initialize-SoftwareTab] Controls found:" -ForegroundColor Gray
        Write-Host "  SoftwarePanel: $($null -ne $softwarePanel)" -ForegroundColor Gray
        Write-Host "  ProgressText: $($null -ne $progressText)" -ForegroundColor Gray
        Write-Host "  ProgressBar: $($null -ne $progressBar)" -ForegroundColor Gray
        Write-Host "  ButtonInstallAll: $($null -ne $buttonInstallAll)" -ForegroundColor Gray
        Write-Host "  ButtonRefreshSoftware: $($null -ne $buttonRefreshSoftware)" -ForegroundColor Gray
        
        if (-not $softwarePanel) {
            throw "SoftwarePanel control not found in XAML"
        }
        
        # Clear existing software panel
        $softwarePanel.Children.Clear()
        
        if ($Global:SoftwareList.Count -eq 0) {
            $noSoftwareText = New-Object System.Windows.Controls.TextBlock
            $noSoftwareText.Text = "No software found in configuration."
            $noSoftwareText.Foreground = [System.Windows.Media.Brushes]::Red
            $noSoftwareText.Margin = New-Object System.Windows.Thickness(10)
            $softwarePanel.Children.Add($noSoftwareText)
            Write-Host "[Initialize-SoftwareTab] No software found" -ForegroundColor Yellow
            return
        }
        
        # Create software buttons
        Write-Host "[Initialize-SoftwareTab] Creating buttons for $($Global:SoftwareList.Count) items..." -ForegroundColor Gray
        
        foreach ($software in $Global:SoftwareList) {
            $button = New-Object System.Windows.Controls.Button
            $button.Content = "$($software.name)"
            $button.ToolTip = "Version: $($software.version)`nCategory: $($software.category)"
            $button.Height = 35
            $button.Margin = New-Object System.Windows.Thickness(5)
            $button.Background = [System.Windows.Media.Brushes]::LightBlue
            $button.Tag = $software
            
            # Click Event Handler
            $button.Add_Click({
                Write-Host "[Button Click] Software: $($this.Tag.name)" -ForegroundColor Cyan
                
                if ($Global:IsInstalling) {
                    Write-Host "[Button Click] Installation already in progress" -ForegroundColor Yellow
                    return
                }
                
                $Global:IsInstalling = $true
                try {
                    $selectedSoftware = $this.Tag
                    Write-Host "[Button Click] Starting installation: $($selectedSoftware.name)" -ForegroundColor Green
                    
                    $result = Install-Software -Software $selectedSoftware -Window $Window
                    Write-Host "[Button Click] Installation result: $result" -ForegroundColor Green
                }
                catch {
                    Write-Host "[Button Click] ERROR: $($_.Exception.Message)" -ForegroundColor Red
                }
                finally {
                    $Global:IsInstalling = $false
                }
            })
            
            $softwarePanel.Children.Add($button)
        }
        
        Write-Host "[Initialize-SoftwareTab] Completed with $($Global:SoftwareList.Count) buttons" -ForegroundColor Green
    }
    catch {
        Write-Host "[Initialize-SoftwareTab] ERROR: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Install-Software {
    param(
        [PSCustomObject]$Software,
        [System.Windows.Window]$Window
    )
    
    $softwareName = $Software.name
    $networkPath = $Software.networkPath
    $silentArgs = $Software.silentArgs
    
    Write-Host "[Install-Software] Starting installation: $softwareName" -ForegroundColor Cyan
    
    try {
        # Show start message
        [System.Windows.MessageBox]::Show("Starting installation of: $softwareName", "Installation", "OK", "Information") | Out-Null
        
        # Check network path
        Write-Host "[Install-Software] Checking network path: $networkPath" -ForegroundColor Gray
        if (-not (Test-Path $networkPath)) {
            throw "Network path not accessible: $networkPath"
        }
        
        # Copy file locally
        Write-Host "[Install-Software] Copying installer..." -ForegroundColor Gray
        $fileName = [System.IO.Path]::GetFileName($networkPath)
        $localPath = Join-Path $env:TEMP $fileName
        Copy-Item -Path $networkPath -Destination $localPath -Force
        
        # Try to unblock file
        try { Unblock-File -Path $localPath -ErrorAction SilentlyContinue } catch { }
        
        # Run installer
        Write-Host "[Install-Software] Running installer with args: $silentArgs" -ForegroundColor Gray
        $process = Start-Process -FilePath $localPath -ArgumentList $silentArgs -Wait -PassThru -NoNewWindow
        
        # Show result
        if ($process.ExitCode -eq 0) {
            [System.Windows.MessageBox]::Show("$softwareName installed successfully!", "Success", "OK", "Information") | Out-Null
            Write-Host "[Install-Software] Installation successful" -ForegroundColor Green
            return $true
        } else {
            [System.Windows.MessageBox]::Show("$softwareName installation completed with exit code: $($process.ExitCode)", "Completed", "OK", "Information") | Out-Null
            Write-Host "[Install-Software] Installation completed with exit code: $($process.ExitCode)" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        $errorMsg = "Failed to install $softwareName : $($_.Exception.Message)"
        [System.Windows.MessageBox]::Show($errorMsg, "Error", "OK", "Error") | Out-Null
        Write-Host "[Install-Software] ERROR: $errorMsg" -ForegroundColor Red
        return $false
    }
    finally {
        if ($localPath -and (Test-Path $localPath)) {
            Remove-Item -Path $localPath -Force -ErrorAction SilentlyContinue
        }
        Write-Host "[Install-Software] Cleanup completed" -ForegroundColor Gray
    }
}

# Export functions
Export-ModuleMember -Function Get-SoftwareConfig, Initialize-SoftwareTab, Install-Software