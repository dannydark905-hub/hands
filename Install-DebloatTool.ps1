<#
.SYNOPSIS
    Installs the Windows 10 Debloat Tool.

.DESCRIPTION
    Copies Windows10-Debloat-GUI.ps1 into Program Files, creates Start Menu
    (and optionally Desktop) shortcuts that launch it elevated, and registers
    the tool in Add/Remove Programs so it can be uninstalled normally.

    The tool is a plain PowerShell script, so no build step or third-party
    runtime is required. This installer only stages the file and shortcuts.

.PARAMETER InstallDir
    Target folder. Defaults to "$env:ProgramFiles\Windows10DebloatTool".

.PARAMETER NoDesktopShortcut
    Skip creating the desktop shortcut (Start Menu shortcut is always made).

.PARAMETER Quiet
    Do not show the summary message box at the end.

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Install-DebloatTool.ps1
#>
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:ProgramFiles "Windows10DebloatTool"),
    [switch]$NoDesktopShortcut,
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

if (-not $Quiet) {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------------
# SELF-ELEVATE
# ------------------------------------------------------------------
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
    if ($InstallDir) { $argList += @("-InstallDir", "`"$InstallDir`"") }
    if ($NoDesktopShortcut) { $argList += "-NoDesktopShortcut" }
    if ($Quiet) { $argList += "-Quiet" }
    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
    } catch {
        Write-Host "Administrator rights are required to install. Elevation was cancelled." -ForegroundColor Red
    }
    exit
}

$AppName        = "Windows 10 Debloat Tool"
$AppVersion     = "1.1.0"
$Publisher      = "hands"
$SourceScript   = Join-Path $PSScriptRoot "Windows10-Debloat-GUI.ps1"
$TargetScript   = Join-Path $InstallDir "Windows10-Debloat-GUI.ps1"
$UninstallerSrc = Join-Path $PSScriptRoot "Uninstall-DebloatTool.ps1"
$UninstallerDst = Join-Path $InstallDir "Uninstall-DebloatTool.ps1"
$UninstallKey   = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Windows10DebloatTool"

function Write-Step { param([string]$Text) Write-Host "  $Text" -ForegroundColor Gray }

# ------------------------------------------------------------------
# SHORTCUT HELPER (with the "Run as administrator" flag)
# ------------------------------------------------------------------
function New-AdminShortcut {
    param(
        [string]$Path,
        [string]$TargetPath,
        [string]$Arguments,
        [string]$WorkingDirectory,
        [string]$IconLocation
    )
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($Path)
    $shortcut.TargetPath = $TargetPath
    $shortcut.Arguments = $Arguments
    $shortcut.WorkingDirectory = $WorkingDirectory
    if ($IconLocation) { $shortcut.IconLocation = $IconLocation }
    $shortcut.Description = $AppName
    $shortcut.Save()

    # Flip the run-as-administrator bit (byte 0x15, mask 0x20) in the .lnk.
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -gt 0x15) {
        $bytes[0x15] = $bytes[0x15] -bor 0x20
        [System.IO.File]::WriteAllBytes($Path, $bytes)
    }
}

Write-Host ""
Write-Host "Installing $AppName $AppVersion" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Cyan

if (-not (Test-Path $SourceScript)) {
    Write-Host "ERROR: Windows10-Debloat-GUI.ps1 was not found next to this installer." -ForegroundColor Red
    Write-Host "Keep Install-DebloatTool.ps1 and Windows10-Debloat-GUI.ps1 in the same folder." -ForegroundColor Red
    exit 1
}

# 1. Copy files
Write-Host "Copying files..." -ForegroundColor Yellow
if (-not (Test-Path $InstallDir)) {
    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
}
Copy-Item -Path $SourceScript -Destination $TargetScript -Force
Write-Step $TargetScript

if (Test-Path $UninstallerSrc) {
    Copy-Item -Path $UninstallerSrc -Destination $UninstallerDst -Force
    Write-Step $UninstallerDst
}

# 2. Shortcuts
Write-Host "Creating shortcuts..." -ForegroundColor Yellow
$powershellExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$launchArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$TargetScript`""

$startMenuDir = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs"
$startMenuLnk = Join-Path $startMenuDir "$AppName.lnk"
New-AdminShortcut -Path $startMenuLnk -TargetPath $powershellExe -Arguments $launchArgs -WorkingDirectory $InstallDir -IconLocation "$powershellExe,0"
Write-Step $startMenuLnk

if (-not $NoDesktopShortcut) {
    $desktopLnk = Join-Path ([Environment]::GetFolderPath("CommonDesktopDirectory")) "$AppName.lnk"
    New-AdminShortcut -Path $desktopLnk -TargetPath $powershellExe -Arguments $launchArgs -WorkingDirectory $InstallDir -IconLocation "$powershellExe,0"
    Write-Step $desktopLnk
}

# 3. Add/Remove Programs entry
Write-Host "Registering with Add/Remove Programs..." -ForegroundColor Yellow
if (-not (Test-Path $UninstallKey)) {
    New-Item -Path $UninstallKey -Force | Out-Null
}
$uninstallString = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$UninstallerDst`""
Set-ItemProperty -Path $UninstallKey -Name "DisplayName"     -Value $AppName
Set-ItemProperty -Path $UninstallKey -Name "DisplayVersion"  -Value $AppVersion
Set-ItemProperty -Path $UninstallKey -Name "Publisher"       -Value $Publisher
Set-ItemProperty -Path $UninstallKey -Name "InstallLocation" -Value $InstallDir
Set-ItemProperty -Path $UninstallKey -Name "UninstallString" -Value $uninstallString
Set-ItemProperty -Path $UninstallKey -Name "DisplayIcon"     -Value "$powershellExe,0"
Set-ItemProperty -Path $UninstallKey -Name "NoModify"         -Value 1 -Type DWord
Set-ItemProperty -Path $UninstallKey -Name "NoRepair"         -Value 1 -Type DWord
Write-Step $UninstallKey

Write-Host ""
Write-Host "Done. Launch it from the Start Menu (\"$AppName\")." -ForegroundColor Green
Write-Host "The shortcut is flagged to run as administrator, so expect a UAC prompt." -ForegroundColor Gray

if (-not $Quiet) {
    [System.Windows.Forms.MessageBox]::Show("$AppName $AppVersion installed to:`r`n$InstallDir`r`n`r`nLaunch it from the Start Menu.", "Installer", "OK", "Information") | Out-Null
}
