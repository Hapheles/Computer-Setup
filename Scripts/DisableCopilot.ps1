# Windows Copilot Removal with Registry Settings
param()

Write-Host "=== Windows Copilot Removal ===" -ForegroundColor Cyan

function Test-Admin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Type,
        [string]$Value,
        [string]$OriginalValue = "<RemoveEntry>"
    )
    
    try {
        # Create registry path if it doesn't exist
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
            Write-Host "  Created registry path: $Path" -ForegroundColor Gray
        }
        
        # Set the registry value
        if ($Value -eq "<RemoveEntry>") {
            Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction SilentlyContinue
            Write-Host "  Removed: $Path\$Name" -ForegroundColor Green
        } else {
            # Convert value based on type
            switch ($Type) {
                "DWord" { $convertedValue = [int]$Value }
                "QWord" { $convertedValue = [long]$Value }
                "String" { $convertedValue = $Value }
                "Binary" { $convertedValue = [byte[]]$Value.Split(',') }
                default { $convertedValue = $Value }
            }
            
            Set-ItemProperty -Path $Path -Name $Name -Value $convertedValue -Type $Type -Force
            Write-Host "  Set: $Path\$Name = $Value ($Type)" -ForegroundColor Green
        }
        return $true
    }
    catch {
        Write-Host "  Failed: $Path\$Name - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

if (-not (Test-Admin)) {
    Write-Host "This script requires Administrator privileges!" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

try {
    Write-Host "Step 1: Applying Copilot Registry Settings..." -ForegroundColor Yellow
    
    # Define all registry settings for Copilot removal
    $registrySettings = @(
        # Group Policy settings
        @{
            Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
            Name = "TurnOffWindowsCopilot"
            Type = "DWord"
            Value = "1"
        },
        @{
            Path = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
            Name = "TurnOffWindowsCopilot" 
            Type = "DWord"
            Value = "1"
        },
        
        # Taskbar button
        @{
            Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            Name = "ShowCopilotButton"
            Type = "DWord"
            Value = "0"
        },
        
        # Copilot availability
        @{
            Path = "HKLM:\SOFTWARE\Microsoft\Windows\Shell\Copilot"
            Name = "IsCopilotAvailable"
            Type = "DWord"
            Value = "0"
        },
        @{
            Path = "HKLM:\SOFTWARE\Microsoft\Windows\Shell\Copilot"
            Name = "CopilotDisabledReason"
            Type = "String"
            Value = "IsEnabledForGeographicRegionFailed"
        },
        
        # Runtime settings
        @{
            Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsCopilot"
            Name = "AllowCopilotRuntime"
            Type = "DWord"
            Value = "0"
        },
        
        # Shell extensions blocking
        @{
            Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked"
            Name = "{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}"
            Type = "String"
            Value = ""
        },
        
        # Bing Chat eligibility
        @{
            Path = "HKLM:\SOFTWARE\Microsoft\Windows\Shell\Copilot\BingChat"
            Name = "IsUserEligible"
            Type = "DWord"
            Value = "0"
        },
        
        # Additional Copilot-related settings
        @{
            Path = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\WindowsCopilot"
            Name = "ConfigureWindowsCopilotButton"
            Type = "DWord"
            Value = "0"
        },
        @{
            Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
            Name = "BingSearchEnabled"
            Type = "DWord"
            Value = "0"
        },
        @{
            Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
            Name = "BingSearchEnabled"
            Type = "DWord"
            Value = "0"
        },
        @{
            Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
            Name = "BuiltInBingSearchEnabled"
            Type = "DWord"
            Value = "0"
        }
    )
    
    # Apply all registry settings
    $successCount = 0
    $totalCount = $registrySettings.Count
    
    foreach ($setting in $registrySettings) {
        $result = Set-RegistryValue @setting
        if ($result) { $successCount++ }
    }
    
    Write-Host "  Applied $successCount of $totalCount registry settings" -ForegroundColor $(if ($successCount -eq $totalCount) { 'Green' } else { 'Yellow' })

    Write-Host "Step 2: Removing Copilot Appx Packages..." -ForegroundColor Yellow
    
    # List of Copilot-related packages to remove
    $copilotPackages = @(
        "Microsoft.Windows.Copilot",
        "Microsoft.Windows.AICopilot", 
        "Microsoft.Copilot",
        "Microsoft.BingChat",
        "Microsoft.BingAI",
        "Microsoft.AI.Copilot"
    )
    
    $removedCount = 0
    foreach ($packageName in $copilotPackages) {
        $packages = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*$packageName*" }
        foreach ($package in $packages) {
            Write-Host "  Removing: $($package.Name)" -ForegroundColor Gray
            try {
                Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                $removedCount++
                Write-Host "  Removed" -ForegroundColor Green
            }
            catch {
                Write-Host "  Failed to remove: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    if ($removedCount -eq 0) {
        Write-Host "  No Copilot Appx packages found to remove" -ForegroundColor Blue
    } else {
        Write-Host "  Removed $removedCount Copilot-related packages" -ForegroundColor Green
    }

    Write-Host "Step 3: Blocking Copilot Domains..." -ForegroundColor Yellow
    
    # Block Copilot-related domains in hosts file
    $hostsPath = "$env:windir\System32\drivers\etc\hosts"
    $copilotDomains = @(
        "127.0.0.1 copilot.microsoft.com",
        "127.0.0.1 copilot-windows.microsoft.com",
        "127.0.0.1 bing.com",
        "127.0.0.1 www.bing.com",
        "127.0.0.1 edgeservices.bing.com",
        "127.0.0.1 api.bing.com",
        "127.0.0.1 copilotsearch.microsoft.com"
    )
    
    $currentHosts = Get-Content $hostsPath -ErrorAction SilentlyContinue
    $domainsAdded = 0
    
    foreach ($domain in $copilotDomains) {
        if ($currentHosts -notcontains $domain) {
            try {
                Add-Content -Path $hostsPath -Value $domain -ErrorAction SilentlyContinue
                $domainsAdded++
            }
            catch {
                Write-Host "  Failed to add domain to hosts file: $domain" -ForegroundColor Red
            }
        }
    }
    
    if ($domainsAdded -gt 0) {
        Write-Host "  Added $domainsAdded domains to hosts file" -ForegroundColor Green
    } else {
        Write-Host "  All domains already blocked" -ForegroundColor Blue
    }

    Write-Host "Step 4: Restarting Explorer to Apply Changes..." -ForegroundColor Yellow
    
    # Restart Explorer to apply taskbar changes
    try {
        Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
        Start-Sleep 3
        Start-Process "explorer.exe"
        Write-Host "  Explorer restarted successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "  Could not restart Explorer: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    Write-Host "`n=== Copilot Removal Complete ===" -ForegroundColor Green
    Write-Host "Registry settings applied: $successCount/$totalCount" -ForegroundColor White
    Write-Host "Appx packages removed: $removedCount" -ForegroundColor White
    Write-Host "Domains blocked: $domainsAdded" -ForegroundColor White
    Write-Host "`nCopilot has been comprehensively disabled and removed from your system." -ForegroundColor White
    Write-Host "A system restart is recommended for all changes to take full effect." -ForegroundColor Yellow

}
catch {
    Write-Host "Error during Copilot removal: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Some operations may have failed. Please check the errors above." -ForegroundColor Red
}

# TODO : Create a restore script
# Write-Host "`nTo restore Copilot, run the 'RestoreCopilot.ps1' script." -ForegroundColor Gray