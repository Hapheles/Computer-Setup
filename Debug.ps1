# Comprehensive debug script
param(
    [string]$XamlPath = "GUI\MainWindow.xaml",
    [string]$ConfigPath = "Configs\Application.json"
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$fullXamlPath = Join-Path $scriptPath $XamlPath
$fullConfigPath = Join-Path $scriptPath $ConfigPath

Write-Host "=== COMPREHENSIVE DEBUG ===" -ForegroundColor Cyan

# Load WPF Assemblies
Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
Add-Type -AssemblyName PresentationCore -ErrorAction Stop
Add-Type -AssemblyName WindowsBase -ErrorAction Stop
Add-Type -AssemblyName System.Xaml -ErrorAction Stop

Write-Host "WPF assemblies loaded" -ForegroundColor Green

# Load and parse XAML
Write-Host "`nLoading XAML from: $fullXamlPath" -ForegroundColor Yellow
$xamlContent = Get-Content -Path $fullXamlPath -Raw
$stringReader = New-Object System.IO.StringReader($xamlContent)
$xmlReader = [System.Xml.XmlReader]::Create($stringReader)
$window = [System.Windows.Markup.XamlReader]::Load($xmlReader)

Write-Host "XAML loaded successfully" -ForegroundColor Green

# Find ALL controls in XAML
Write-Host "`n=== ALL CONTROLS IN XAML ===" -ForegroundColor Yellow

# Method 1: Find named elements
Write-Host "`nNamed Controls (x:Name):" -ForegroundColor White
$namedElements = [regex]::Matches($xamlContent, 'x:Name="([^"]*)"')
foreach ($match in $namedElements) {
    $controlName = $match.Groups[1].Value
    $control = $window.FindName($controlName)
    if ($control) {
        Write-Host "  $controlName - $($control.GetType().Name)" -ForegroundColor Green
    } else {
        Write-Host "  $controlName - NOT FOUND" -ForegroundColor Red
    }
}

# Method 2: Find elements by type
Write-Host "`nControls by Type:" -ForegroundColor White
$controlTypes = @(
    "Button", "TextBlock", "TextBox", "ProgressBar", 
    "CheckBox", "RadioButton", "TabControl", "TabItem",
    "StackPanel", "Grid", "ScrollViewer", "GroupBox"
)

foreach ($type in $controlTypes) {
    $pattern = "<$type[^>]*>"
    $match = [regex]::Matches($xamlContent, $pattern)
    if ($match.Count -gt 0) {
        Write-Host "  $type : $($matches.Count) found" -ForegroundColor Gray
    }
}

# Test specific critical controls
Write-Host "`n=== CRITICAL CONTROLS TEST ===" -ForegroundColor Yellow
$criticalControls = @(
    "SoftwarePanel", "ProgressText", "ProgressBar", 
    "ButtonInstallAll", "ButtonRefreshSoftware", "ButtonExit"
)

foreach ($controlName in $criticalControls) {
    $control = $window.FindName($controlName)
    if ($control) {
        Write-Host "  $controlName : $($control.GetType().Name)" -ForegroundColor Green
    } else {
        Write-Host "  $controlName : MISSING" -ForegroundColor Red
    }
}

# Test software loading
Write-Host "`n=== SOFTWARE CONFIG TEST ===" -ForegroundColor Yellow
if (Test-Path $fullConfigPath) {
    try {
        $jsonContent = Get-Content -Path $fullConfigPath -Raw | ConvertFrom-Json
        Write-Host "  Config loaded: $($jsonContent.software.Count) software items" -ForegroundColor Green
        foreach ($software in $jsonContent.software) {
            Write-Host "    - $($software.name)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  Config error: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "  Config file not found" -ForegroundColor Red
}

$window.Close()
Write-Host "`n=== DEBUG COMPLETE ===" -ForegroundColor Cyan