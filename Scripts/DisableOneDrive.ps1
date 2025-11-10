# Remove OneDrive Script
param()

$OneDrivePath = $env:OneDrive
Write-Host "Removing OneDrive" -ForegroundColor Yellow

# Check both traditional and Microsoft Store installations
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe"
$msStorePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Applications\*OneDrive*"

if (Test-Path $regPath) {
    Write-Host "Found traditional OneDrive installation" -ForegroundColor Green
    $OneDriveUninstallString = Get-ItemPropertyValue "$regPath" -Name "UninstallString"
    $OneDriveExe, $OneDriveArgs = $OneDriveUninstallString.Split(" ")
    Start-Process -FilePath $OneDriveExe -ArgumentList "$OneDriveArgs /silent" -NoNewWindow -Wait
} elseif (Test-Path $msStorePath) {
    Write-Host "OneDrive appears to be installed via Microsoft Store" -ForegroundColor Yellow
    # Attempt to uninstall via winget
    Start-Process -FilePath winget -ArgumentList "uninstall -e --purge --accept-source-agreements Microsoft.OneDrive" -NoNewWindow -Wait
} else {
    Write-Host "OneDrive doesn't seem to be installed" -ForegroundColor Red
}

# Check if OneDrive got Uninstalled (both paths)
if (Test-Path $OneDrivePath) {
    Write-Host "Copying files from OneDrive folder to user profile..." -ForegroundColor Yellow
    Start-Process -FilePath powershell -ArgumentList "robocopy '$($OneDrivePath)' '$($env:USERPROFILE.TrimEnd())\\' /mov /e /xj" -NoNewWindow -Wait

    Write-Host "Removing OneDrive leftovers..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$env:localappdata\Microsoft\OneDrive"
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$env:localappdata\OneDrive"
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$env:programdata\Microsoft OneDrive"
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$env:systemdrive\OneDriveTemp"
    
    # Remove registry entries
    reg delete "HKEY_CURRENT_USER\Software\Microsoft\OneDrive" /f 2>$null
    
    # Remove from Explorer sidebar
    Set-ItemProperty -Path "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Name "System.IsPinnedToNameSpaceTree" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Name "System.IsPinnedToNameSpaceTree" -Value 0 -ErrorAction SilentlyContinue

    Write-Host "Restarting Explorer..." -ForegroundColor Yellow
    taskkill.exe /F /IM "explorer.exe" 2>$null
    Start-Sleep 2
    Start-Process "explorer.exe"
    
    Write-Host "OneDrive removal completed!" -ForegroundColor Green
} else {
    Write-Host "No OneDrive cleanup needed" -ForegroundColor Green
}