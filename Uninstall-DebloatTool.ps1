<#
.SYNOPSIS
    Uninstalls the Windows 10 Debloat Tool.

.DESCRIPTION
    Removes the installed files, Start Menu / desktop shortcuts, and the
    Add/Remove Programs registry entry created by Install-DebloatTool.ps1.

.PARAMETER InstallDir
    Folder the tool was installed to. Defaults to "$env:ProgramFiles\Windows10DebloatTool".

.PARAMETER KeepLog
    Keep Debloat-Log.txt from the install folder instead of deleting it.

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Uninstall-DebloatTool.ps1
#>
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:ProgramFiles "Windows10DebloatTool"),
    [switch]$KeepLog
)

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------------
# SELF-ELEVATE
# ------------------------------------------------------------------
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"", "-InstallDir", "`"$InstallDir`"")
    if ($KeepLog) { $argList += "-KeepLog" }
    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
    } catch {
        Write-Host "Administrator rights are required to uninstall. Elevation was cancelled." -ForegroundColor Red
    }
    exit
}

$AppName      = "Windows 10 Debloat Tool"
$UninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Windows10DebloatTool"

Write-Host ""
Write-Host "Uninstalling $AppName" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Cyan

# 1. Shortcuts
$startMenuLnk = Join-Path (Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs") "$AppName.lnk"
$desktopLnk   = Join-Path ([Environment]::GetFolderPath("CommonDesktopDirectory")) "$AppName.lnk"
foreach ($lnk in @($startMenuLnk, $desktopLnk)) {
    if (Test-Path $lnk) {
        Remove-Item -Path $lnk -Force
        Write-Host "  Removed shortcut: $lnk" -ForegroundColor Gray
    }
}

# 2. Add/Remove Programs entry
if (Test-Path $UninstallKey) {
    Remove-Item -Path $UninstallKey -Recurse -Force
    Write-Host "  Removed Add/Remove Programs entry." -ForegroundColor Gray
}

# 3. Files
if (Test-Path $InstallDir) {
    if ($KeepLog) {
        $log = Join-Path $InstallDir "Debloat-Log.txt"
        if (Test-Path $log) {
            $keep = Join-Path ([Environment]::GetFolderPath("Desktop")) "Debloat-Log.txt"
            Copy-Item -Path $log -Destination $keep -Force
            Write-Host "  Kept log copy at: $keep" -ForegroundColor Gray
        }
    }
    Remove-Item -Path $InstallDir -Recurse -Force
    Write-Host "  Removed install folder: $InstallDir" -ForegroundColor Gray
} else {
    Write-Host "  Install folder not found (already removed?): $InstallDir" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Done. $AppName has been uninstalled." -ForegroundColor Green
Write-Host "Note: any apps/settings the tool changed are NOT reverted by this uninstaller." -ForegroundColor Yellow
