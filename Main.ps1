param(
    [string]$ConfigPath,
    [string]$XamlPath
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $ConfigPath) {
    $ConfigPath = Join-Path $scriptPath "Configs\Application.json"
}
if (-not $XamlPath) {
    $XamlPath = Join-Path $scriptPath "GUI\MainWindow.xaml"
}

# Admin Relaunch Code
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "System Manager needs to be run as Administrator. Attempting to relaunch."
    
    $argList = @()
    if ($ConfigPath) { $argList += "-ConfigPath"; $argList += "`"$ConfigPath`"" }
    if ($XamlPath) { $argList += "-XamlPath"; $argList += "`"$XamlPath`"" }
    
    $script = "& { & `'$($PSCommandPath)`' $($argList -join ' ') }"
    $powershellCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
    
    Start-Process $powershellCmd -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
    break
}

Write-Host "=== System Manager ===" -ForegroundColor Cyan

# Verify files exist
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    exit 1
}

if (-not (Test-Path $XamlPath)) {
    Write-Error "XAML file not found: $XamlPath"
    exit 1
}

# Load WPF Assemblies
try {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Xaml
    Write-Host " WPF assemblies loaded" -ForegroundColor Green
}
catch {
    Write-Error "Failed to load WPF assemblies: $($_.Exception.Message)"
    exit 1
}

# Import Modules
$modulesPath = Join-Path $scriptPath "Modules"
$modules = @(
    @{ Name = "ApplicationInstaller"; File = "ApplicationInstaller.psm1" },
    @{ Name = "SystemSettings"; File = "SystemSettings.psm1" }
)

foreach ($module in $modules) {
    $modulePath = Join-Path $modulesPath $module.File
    if (Test-Path $modulePath) {
        try {
            Import-Module $modulePath -Force -ErrorAction Stop
            Write-Host " Loaded module: $($module.Name)" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to load module $($module.Name): $($_.Exception.Message)"
        }
    }
}

# Global Variables
$Global:SoftwareList = @()
$Global:IsInstalling = $false

# Main Execution 
try {
    Write-Host "`nLoading configuration..." -ForegroundColor White
    $Global:SoftwareList = Get-SoftwareConfig -Path $ConfigPath
    Write-Host " Loaded $($Global:SoftwareList.Count) software packages" -ForegroundColor Green

    Write-Host "Loading XAML..." -ForegroundColor White
    $xamlContent = Get-Content -Path $XamlPath -Raw
    $stringReader = New-Object System.IO.StringReader($xamlContent)
    $xmlReader = [System.Xml.XmlReader]::Create($stringReader)
    $window = [System.Windows.Markup.XamlReader]::Load($xmlReader)
    Write-Host " XAML loaded successfully" -ForegroundColor Green

    # Verify critical controls exist before initializing
    Write-Host "Verifying UI controls..." -ForegroundColor White
    $criticalControls = @("SoftwarePanel", "ProgressText", "ProgressBar", "ButtonExit")
    $missingControls = @()
    
    foreach ($controlName in $criticalControls) {
        $control = $window.FindName($controlName)
        if (-not $control) {
            $missingControls += $controlName
            Write-Host "  Missing: $controlName" -ForegroundColor Red
        } else {
            Write-Host "  Found: $controlName" -ForegroundColor Green
        }
    }

    if ($missingControls.Count -gt 0) {
        throw "Missing critical controls: $($missingControls -join ', '). Please check your XAML file."
    }

    # Initialize tabs
    Write-Host "Initializing software tab..." -ForegroundColor White
    Initialize-SoftwareTab -Window $window -ConfigPath $ConfigPath

    Write-Host "Initializing settings tab..." -ForegroundColor White
    $settingsConfigPath = Join-Path $scriptPath "Configs\SystemSetting.json"
    Initialize-SettingsTab -Window $window -SettingsPath $settingsConfigPath

    # Set up exit button
    $buttonExit = $window.FindName("ButtonExit")
    $buttonExit.Add_Click({ 
        Write-Host "Closing application..." -ForegroundColor Yellow
        $window.Close() 
    })

    Write-Host "`n Application initialized successfully" -ForegroundColor Green
    Write-Host "Showing window..." -ForegroundColor White

    # Show the window
    $null = $window.ShowDialog()
    
    Write-Host "System Manager closed." -ForegroundColor Cyan
}
catch {
    Write-Host "`n CRITICAL ERROR" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.Exception.StackTrace)" -ForegroundColor Red
    
    # Show detailed error message
    $errorMsg = @"
Critical Error Details:

Message: $($_.Exception.Message)
Type: $($_.Exception.GetType().Name)

This usually means:
1. A control is missing from the XAML file
2. There's an error in the button click event handler
3. A function is trying to use a control that doesn't exist

Please run .\Debug.ps1 to check your XAML file.
"@
    
    [System.Windows.MessageBox]::Show($errorMsg, "Critical Error", "OK", "Error") | Out-Null
    pause
}