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
        
        Write-Host "[Initialize-SoftwareTab] Controls found:" -ForegroundColor Gray
        Write-Host "  SoftwarePanel: $($null -ne $softwarePanel)" -ForegroundColor Gray
        
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

        #Group software by category
        $categories = $Global:SoftwareList | Group-Object category | Sort-Object Name

        Write-Host "[Intialize-SoftwareTab] Found$($categories.Count) categories" -ForegroundColor Gray

        foreach ($category in $categories) {
            Write-Host "[Initialize-SoftwareTab] Processing category: $($category.Name). Category Count: $($categories.Count) items" - Foreground Gray

            # category header with styling
            $categoryHeader = New-Object System.Windows.Controls.TextBlock
            $categoryHeader.Text = $category.Name.ToUpper()
            $categoryHeader.FontWeight =  [System.Windows.FontWeight]::Bold
            $categoryHeader.FontSize = 16;
            $categoryHeader.Margin = New-object System.Windows.Thickness(0, 15, 0, 5)
            $categoryHeader.Foreground = [System.Windows.Media.Brushes]::DarkBlue
            $categoryHeader.Background = [System.Windows.Media.Brushes]::LightGray
            $categoryHeader.Padding = New-Object System.Windows.Thickness(5)
            $softwarePanel.Children.Add($categoryheader)

            # category count badge
            $countBadge = New-Object System.Windows.Controls.TextBlock
            $countBadge.Text = "[$($category.Count) application]"
            $countBadge.FontSize = 12
            $countBadge.Foreground = [System.Windows.Media.Brushes]::Gray
            $countBadge.FontStyle = [System.Windows.Media.FontStyle]::Italic
            $categoryHeader.InLines.Add($countBadge)

            # Seperator line
            $separator = New-Object System.Windows.Controls.Border
            $separator.Height = 2
            $separator.Background = [System.Windows.Media.Brushes]::LightGray
            $separator.Margin = New-Object System.Windows.Thickness(0,0,0,10)
            $softwarePanel.Children.Add($separator)

            # Add software buttons for this category in a grid layout
            $itemsWrapPanel = New-Object System.Windows.Controls.WrapPanel
            $itemsWrapPanel.Orientation = "Horizontal"
            $itemsWrapPanel.HorizontalAlignment = "Left"

            foreach ($software in $category.Group | Sort-Object name) {
                Write-Host "[Initialize-SoftwareTab] Creating buttons for $($Global:SoftwareList.Count) items..." -ForegroundColor Gray

                # Create borders
                $buttonBorder = New-Object System.Windows.Controls.Border
                $buttonBorder.BorderThickness = New-Object System.Windows.Thickness(1)
                $buttonBorder.BorderBrush = [System.Windows.Media.Brushes]::LightGray
                $buttonBorder.CornerRadius = New-Object System.Windows.CornerRadius(5)
                $buttonBorder.Margin = New-Object System.Windows.Thickness(5)
                $buttonBorder.Background = [System.Windows.Media.Brushes]::White
                $buttonBorder.Width = 200
                $buttonBorder.Height = 80
                
                # Create stack panel for button content
                $stackPanel = New-Object System.Windows.Controls.StackPanel
                $stackPanel.Orientation = "Vertical"
                $stackPanel.Margin = New-Object System.Windows.Thickness(5)
                
                # Software name
                $nameText = New-Object System.Windows.Controls.TextBlock
                $nameText.Text = $software.name
                $nameText.FontWeight = [System.Windows.FontWeights]::Bold
                $nameText.FontSize = 12
                $nameText.TextWrapping = [System.Windows.TextWrapping]::Wrap
                $stackPanel.Children.Add($nameText)
                
                # Version
                $versionText = New-Object System.Windows.Controls.TextBlock
                $versionText.Text = "v$($software.version)"
                $versionText.FontSize = 10
                $versionText.Foreground = [System.Windows.Media.Brushes]::Gray
                $stackPanel.Children.Add($versionText)
                
                # Install button
                $installButton = New-Object System.Windows.Controls.Button
                $installButton.Content = "Install"
                $installButton.Height = 25
                $installButton.Width = 80
                $installButton.Margin = New-Object System.Windows.Thickness(0,5,0,0)
                $installButton.HorizontalAlignment = "Left"
                $installButton.Background = [System.Windows.Media.Brushes]::LightSteelBlue
                $installButton.Tag = $software

                # Add Click Event
                $installButton.Add_Click({
                    Write-Host "[Button Click] Software: $($this.Tag.name)" -ForegroundColor Cyan

                    if ($Global:IsInstalling) {
                        Write-Host "[Button Click] Installation already in progress" -ForegroundColor Yellow
                        [System.Windows.MessageBox]::Show("Please wait for current installation to complete.", "Busy", "OK", "Warning") | Out-Null
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
                        Write-Host "[Button Click] ERROR in click handler: $($_.Exception.Message)" -ForegroundColor Red
                        [System.Windows.MessageBox]::Show("Error starting installation: $($_.Exception.Message)", "Error", "OK", "Error") | Out-Null
                    }
                    finally {
                        $Global:IsInstalling = $false
                    }
                })

                $stackPanel.Children.Add($installButton)
                $buttonBorder.Child = $stackPanel
                $itemsWrapPanel.Children.Add($buttonBorder)
            }

            $softwarePanel.Children.Add($itemsWrapPanel)
        }
                
        Write-Host "[Initialize-SoftwareTab] Completed with $($categories.Count) categories" -ForegroundColor Green
    }
    catch {
        Write-Host "[Initialize-SoftwareTab] ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack trace: $($_.Exception.StackTrace)" -ForegroundColor Red
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