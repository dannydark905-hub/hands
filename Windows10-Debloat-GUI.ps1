<#
.SYNOPSIS
    Windows 10 Debloat Tool - GUI Edition

.DESCRIPTION
    A point-and-click front end for debloating Windows 10: pick which
    pre-installed apps to remove, toggle telemetry/ads settings, then
    click Run. Progress and results are shown live in the log pane and
    saved to Debloat-Log.txt next to the script.

    The list is populated for the Windows 10 app set. If the tool is run
    on Windows 11 the additional Windows 11-only packages are appended
    automatically.

.NOTES
    - Self-elevates: if you don't run it as Administrator, it will
      relaunch itself with a UAC prompt.
    - Nothing runs until you click "Run Selected" and confirm the summary.
    - Everything it does is reversible via the System Restore Point it
      offers to create, or by re-enabling toggles / reinstalling apps.

.USAGE
    Right-click -> Run with PowerShell
    (or) powershell.exe -ExecutionPolicy Bypass -File .\Windows10-Debloat-GUI.ps1
#>

# ------------------------------------------------------------------
# SELF-ELEVATE
# ------------------------------------------------------------------
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    $psi = @{
        FilePath     = "powershell.exe"
        ArgumentList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Verb         = "RunAs"
    }
    try {
        Start-Process @psi
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Administrator rights are required and the elevation prompt was cancelled.", "Debloat Tool", "OK", "Error") | Out-Null
    }
    exit
}

# DPI awareness must be set before any window is created, otherwise the UI
# is bitmap-scaled (blurry) on high-DPI displays. The type only exists on
# .NET Framework 4.7+, so it is created defensively.
try {
    Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public static class DpiHelper {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@ -ErrorAction Stop
    [void][DpiHelper]::SetProcessDPIAware()
} catch { }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ------------------------------------------------------------------
# PLATFORM DETECTION
# ------------------------------------------------------------------
function Get-PlatformInfo {
    try {
        $v = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop
        $name = $v.ProductName
        $build = [int]$v.CurrentBuildNumber
        if ($name -notmatch 'Windows 1[01]') { $name = "Windows 10/11" }
        $family = if ($build -ge 22000) { "Windows 11" } else { "Windows 10" }
        return [pscustomobject]@{
            ProductName = $name
            Family      = $family
            Build       = $build
            Version     = $v.DisplayVersion
        }
    } catch {
        return [pscustomobject]@{ ProductName = "Windows"; Family = "Windows 10"; Build = 0; Version = "" }
    }
}
$script:Platform = Get-PlatformInfo

# ------------------------------------------------------------------
# DATA: apps available for removal (DisplayName shown in list, Id used to match packages)
# ------------------------------------------------------------------
$AppCatalog = @(
    # --- Windows 10 bloat ---
    @{ Display = "3D Builder / 3D Viewer";        Id = "*3DBuilder*";  Group = "Bloat" }
    @{ Display = "Cortana";                        Id = "Microsoft.549981C3F5F10"; Group = "Bloat" }
    @{ Display = "Bing Weather";                   Id = "Microsoft.BingWeather"; Group = "Bloat" }
    @{ Display = "Bing News";                      Id = "Microsoft.BingNews"; Group = "Bloat" }
    @{ Display = "Bing Finance";                   Id = "Microsoft.BingFinance"; Group = "Bloat" }
    @{ Display = "Bing Sports";                    Id = "Microsoft.BingSports"; Group = "Bloat" }
    @{ Display = "Get Help";                       Id = "Microsoft.GetHelp"; Group = "Bloat" }
    @{ Display = "Tips (Get Started)";             Id = "Microsoft.Getstarted"; Group = "Bloat" }
    @{ Display = "Messaging";                      Id = "Microsoft.Messaging"; Group = "Bloat" }
    @{ Display = "Office Hub";                     Id = "Microsoft.MicrosoftOfficeHub"; Group = "Bloat" }
    @{ Display = "Solitaire Collection";           Id = "Microsoft.MicrosoftSolitaireCollection"; Group = "Bloat" }
    @{ Display = "Sticky Notes";                   Id = "Microsoft.MicrosoftStickyNotes"; Group = "Bloat" }
    @{ Display = "Mixed Reality Portal";           Id = "Microsoft.MixedReality.Portal"; Group = "Bloat" }
    @{ Display = "Network Speed Test";             Id = "Microsoft.NetworkSpeedTest"; Group = "Bloat" }
    @{ Display = "OneNote (Store version)";        Id = "Microsoft.Office.OneNote"; Group = "Bloat" }
    @{ Display = "Sway";                           Id = "Microsoft.Office.Sway"; Group = "Bloat" }
    @{ Display = "People";                         Id = "Microsoft.People"; Group = "Bloat" }
    @{ Display = "Print 3D";                       Id = "Microsoft.Print3D"; Group = "Bloat" }
    @{ Display = "Skype";                          Id = "Microsoft.SkypeApp"; Group = "Bloat" }
    @{ Display = "Microsoft Wallet";               Id = "Microsoft.Wallet"; Group = "Bloat" }
    @{ Display = "Whiteboard";                     Id = "Microsoft.Whiteboard"; Group = "Bloat" }
    @{ Display = "Alarms & Clock";                 Id = "Microsoft.WindowsAlarms"; Group = "Bloat" }
    @{ Display = "Camera";                         Id = "Microsoft.WindowsCamera"; Group = "Bloat" }
    @{ Display = "Mail and Calendar";              Id = "microsoft.windowscommunicationsapps"; Group = "Bloat" }
    @{ Display = "Feedback Hub";                   Id = "Microsoft.WindowsFeedbackHub"; Group = "Bloat" }
    @{ Display = "Maps";                           Id = "Microsoft.WindowsMaps"; Group = "Bloat" }
    @{ Display = "Sound Recorder";                 Id = "Microsoft.WindowsSoundRecorder"; Group = "Bloat" }
    @{ Display = "Xbox apps (all)";                Id = "*Xbox*"; Group = "Bloat" }
    @{ Display = "Your Phone / Phone Link";        Id = "Microsoft.YourPhone"; Group = "Bloat" }
    @{ Display = "Groove Music";                   Id = "Microsoft.ZuneMusic"; Group = "Bloat" }
    @{ Display = "Movies & TV";                    Id = "Microsoft.ZuneVideo"; Group = "Bloat" }
    @{ Display = "Microsoft Teams (consumer)";     Id = "MicrosoftTeams"; Group = "Bloat" }
    @{ Display = "Microsoft To Do";                Id = "Microsoft.Todos"; Group = "Bloat" }
    @{ Display = "Power Automate Desktop";         Id = "Microsoft.PowerAutomateDesktop"; Group = "Bloat" }
    @{ Display = "New Outlook";                    Id = "Microsoft.OutlookForWindows"; Group = "Bloat" }
    @{ Display = "Clipchamp";                      Id = "Clipchamp.Clipchamp"; Group = "Bloat" }
    @{ Display = "Web Experience Pack (widgets/news feed)"; Id = "MicrosoftWindows.Client.WebExperience"; Group = "Bloat" }
    # --- Windows 11 only (filtered out on Windows 10) ---
    @{ Display = "Widgets Platform Runtime";       Id = "Microsoft.WidgetsPlatformRuntime"; Group = "Bloat"; MinBuild = 22000 }
    @{ Display = "Windows Copilot";                Id = "Microsoft.Copilot"; Group = "Bloat"; MinBuild = 22000 }
    @{ Display = "Xbox Game Bar (Win11)";          Id = "Microsoft.XboxGamingOverlay"; Group = "Bloat"; MinBuild = 22000 }
    @{ Display = "Quick Assist (Win11)";           Id = "Microsoft.QuickAssist"; Group = "Bloat"; MinBuild = 22000 }
    # --- OEM trials ---
    @{ Display = "Facebook (OEM)";                 Id = "*Facebook*"; Group = "OEM" }
    @{ Display = "Twitter (OEM)";                  Id = "*Twitter*"; Group = "OEM" }
    @{ Display = "Spotify (OEM)";                  Id = "*Spotify*"; Group = "OEM" }
    @{ Display = "Disney+ (OEM)";                  Id = "*Disney*"; Group = "OEM" }
    @{ Display = "Candy Crush (OEM)";               Id = "*CandyCrush*"; Group = "OEM" }
    @{ Display = "Bubble Witch (OEM)";              Id = "*BubbleWitch*"; Group = "OEM" }
    @{ Display = "McAfee (OEM)";                   Id = "*McAfee*"; Group = "OEM" }
    @{ Display = "Dolby Access (OEM)";              Id = "*Dolby*"; Group = "OEM" }
)

function Get-CuratedApps {
    $build = $script:Platform.Build
    return @($AppCatalog | Where-Object { -not $_.MinBuild -or $build -ge $_.MinBuild })
}

# ------------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------------
$script:LogFile = Join-Path $PSScriptRoot "Debloat-Log.txt"
function Write-Log {
    param([string]$Text, [string]$Color = "Black")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $line = "[$timestamp] $Text"
    $LogBox.SelectionStart = $LogBox.TextLength
    $LogBox.SelectionLength = 0
    $LogBox.SelectionColor = [System.Drawing.Color]::$Color
    $LogBox.AppendText("$line`r`n")
    $LogBox.ScrollToCaret()
    Add-Content -Path $script:LogFile -Value $line -ErrorAction SilentlyContinue
    [System.Windows.Forms.Application]::DoEvents()
}

# ------------------------------------------------------------------
# APP LIST MODEL
#
# The checked set is tracked as a hashtable of Ids ($script:Checked), never by
# list index. The list box is only a view of $script:CurrentApps, so filtering
# or reloading it can never desync the selection from the backing data.
# ------------------------------------------------------------------
$script:ViewMode    = "Curated"   # "Curated" | "InstalledAppx" | "Desktop"
$script:CurrentApps = Get-CuratedApps
$script:Checked     = @{}
$script:Filter      = ""

function Get-InstalledAppItems {
    Write-Log "Scanning installed Store (UWP) apps (this can take a few seconds)..." "Yellow"
    try {
        $pkgs = Get-AppxPackage -AllUsers -ErrorAction Stop
    } catch {
        $pkgs = Get-AppxPackage -ErrorAction SilentlyContinue
    }
    $pkgs = $pkgs | Where-Object { -not $_.IsFramework -and -not $_.NonRemovable } | Sort-Object Name
    $items = @()
    foreach ($p in $pkgs) {
        $items += @{ Display = $p.Name; Id = $p.Name; Kind = "Appx" }
    }
    Write-Log "Found $($items.Count) removable Store apps." "LightGreen"
    return $items
}

function Get-DesktopAppItems {
    Write-Log "Scanning installed desktop (Win32) programs (this can take a few seconds)..." "Yellow"
    $roots = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $seen = @{}
    $items = @()
    foreach ($root in $roots) {
        Get-ItemProperty -Path $root -ErrorAction SilentlyContinue | ForEach-Object {
            $name = $_.DisplayName
            if (-not $name) { return }
            if ($_.SystemComponent -eq 1) { return }
            if (-not $_.UninstallString -and -not $_.QuietUninstallString) { return }

            $key = "$name|$($_.Publisher)"
            if ($seen.ContainsKey($key)) { return }
            $seen[$key] = $true

            $isMsi = $false
            $productCode = $null
            if ($_.PSChildName -match '^\{[0-9A-Fa-f\-]+\}$') {
                $isMsi = $true
                $productCode = $_.PSChildName
            }

            $displayText = if ($_.DisplayVersion) { "$name ($($_.DisplayVersion))" } else { $name }
            if ($_.Publisher) { $displayText += "  -  $($_.Publisher)" }

            $items += @{
                Display               = $displayText
                Id                    = $key
                Kind                  = "Desktop"
                UninstallString       = $_.UninstallString
                QuietUninstallString  = $_.QuietUninstallString
                IsMSI                 = $isMsi
                ProductCode           = $productCode
            }
        }
    }
    $items = @($items | Sort-Object { $_.Display })
    Write-Log "Found $($items.Count) installed desktop programs." "LightGreen"
    return $items
}

function Set-AppListItems {
    param($Items, [bool]$DefaultChecked = $true)
    $script:CurrentApps = $Items
    $script:Checked = @{}
    if ($DefaultChecked) {
        foreach ($it in $Items) { $script:Checked[$it.Id] = $true }
    }
    $script:Filter = ""
    $SearchBox.Clear()
    Update-ListDisplay
}

function Get-VisibleApps {
    if ($script:Filter) { return @($script:CurrentApps | Where-Object { $_.Display -like "*$script:Filter*" }) }
    return @($script:CurrentApps)
}

function Update-ListDisplay {
    $AppList.BeginUpdate()
    try {
        $AppList.Items.Clear()
        foreach ($it in Get-VisibleApps) {
            $text = $it.Display
            if ($it.ContainsKey("Installed")) {
                $text += if ($it.Installed) { "  -  Installed" } else { "  -  Not installed" }
            }
            [void]$AppList.Items.Add($text, [bool]$script:Checked[$it.Id])
        }
    } finally {
        $AppList.EndUpdate()
    }
    Update-ListSummary
}

function Update-ListSummary {
    $visible = @(Get-VisibleApps)
    $checked = @($script:Checked.Keys | Where-Object { $script:Checked[$_] }).Count
    $StatusLabel.Text = "Showing $($visible.Count) of $($script:CurrentApps.Count) item(s) - $checked selected - $($script:Platform.Family) (build $($script:Platform.Build))."
}

function Load-View {
    param([string]$Mode)
    switch ($Mode) {
        "Curated" {
            Set-AppListItems -Items (Get-CuratedApps) -DefaultChecked:$true
        }
        "InstalledAppx" {
            $items = Get-InstalledAppItems
            Set-AppListItems -Items $items -DefaultChecked:$false
            # Pre-check anything matching a known bloat/OEM pattern for convenience
            $catalog = Get-CuratedApps
            foreach ($it in $items) {
                if ($catalog | Where-Object { $it.Id -like $_.Id }) { $script:Checked[$it.Id] = $true }
            }
            Update-ListDisplay
        }
        "Desktop" {
            $items = Get-DesktopAppItems
            Set-AppListItems -Items $items -DefaultChecked:$false
        }
    }
    $script:ViewMode = $Mode
}

# ------------------------------------------------------------------
# PRESETS
# ------------------------------------------------------------------
function Apply-Preset {
    param([string]$Name)
    # Safe: leave browsers, comms, media and Store-adjacent apps alone.
    $safeKeep = @(
        "Microsoft.WindowsCamera", "Microsoft.WindowsAlarms", "Microsoft.WindowsSoundRecorder",
        "Microsoft.WindowsMaps", "Microsoft.MicrosoftStickyNotes", "Microsoft.People",
        "microsoft.windowscommunicationsapps", "Microsoft.YourPhone", "MicrosoftTeams",
        "Microsoft.Todos", "Microsoft.PowerAutomateDesktop", "Microsoft.OutlookForWindows",
        "Microsoft.MicrosoftOfficeHub", "Microsoft.Office.OneNote", "Microsoft.Office.Sway"
    )

    foreach ($app in $script:CurrentApps) {
        $check = switch ($Name) {
            "Safe"        { -not ($safeKeep -contains $app.Id) }
            "Recommended" { $true }
            "Aggressive"  { $true }
            default       { [bool]$script:Checked[$app.Id] }
        }
        $script:Checked[$app.Id] = [bool]$check
    }
    switch ($Name) {
        "Safe"        { $chkRestore.Checked = $true; $chkTelemetry.Checked = $true; $chkAds.Checked = $true; $chk3D.Checked = $false }
        "Recommended" { $chkRestore.Checked = $true; $chkTelemetry.Checked = $true; $chkAds.Checked = $true; $chk3D.Checked = $true }
        "Aggressive"  { $chkRestore.Checked = $true; $chkTelemetry.Checked = $true; $chkAds.Checked = $true; $chk3D.Checked = $true }
    }
    Update-ListDisplay
}

# ------------------------------------------------------------------
# RESULT TRACKING
# ------------------------------------------------------------------
$script:Results = @()
function Add-Result {
    param([string]$Name, [string]$Outcome)
    $script:Results += [pscustomobject]@{ Name = $Name; Outcome = $Outcome }
}

function Show-Results {
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Dock = "Fill"
    $grid.ReadOnly = $true
    $grid.AllowUserToAddRows = $false
    $grid.AutoSizeColumnsMode = "Fill"
    $grid.RowHeadersVisible = $false
    $grid.DataSource = $script:Results
    if ($grid.Columns.Count -ge 2) {
        $grid.Columns[0].HeaderText = "Item"
        $grid.Columns[1].HeaderText = "Result"
    }

    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "Run Results ($($script:Results.Count) item(s))"
    $dlg.Size = New-Object System.Drawing.Size(620, 460)
    $dlg.StartPosition = "CenterParent"
    $dlg.MinimizeBox = $false
    $close = New-Object System.Windows.Forms.Button
    $close.Text = "Close"
    $close.Dock = "Bottom"
    $close.Add_Click({ $dlg.Close() })
    $dlg.Controls.Add($grid)
    $dlg.Controls.Add($close)
    [void]$dlg.ShowDialog($Form)
}

# ------------------------------------------------------------------
# BUILD FORM
# ------------------------------------------------------------------
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Windows 10 Debloat Tool"
$Form.Size = New-Object System.Drawing.Size(780, 800)
$Form.MinimumSize = New-Object System.Drawing.Size(700, 640)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "Sizable"
$Form.MaximizeBox = $true
$Form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# --- Title / platform banner ---
$TitleLabel = New-Object System.Windows.Forms.Label
$TitleLabel.Text = "Select apps to remove and options to apply, then click Run."
$TitleLabel.Location = New-Object System.Drawing.Point(15, 10)
$TitleLabel.Size = New-Object System.Drawing.Size(600, 20)
$TitleLabel.Anchor = "Top,Left,Right"
$Form.Controls.Add($TitleLabel)

$PlatformLabel = New-Object System.Windows.Forms.Label
$PlatformLabel.Text = "$($script:Platform.ProductName) (build $($script:Platform.Build)) - $($script:Platform.Family) app list loaded."
$PlatformLabel.Location = New-Object System.Drawing.Point(15, 30)
$PlatformLabel.Size = New-Object System.Drawing.Size(600, 18)
$PlatformLabel.Anchor = "Top,Left,Right"
$PlatformLabel.ForeColor = [System.Drawing.Color]::DimGray
$Form.Controls.Add($PlatformLabel)

# --- View / preset / filter row ---
$ViewLabel = New-Object System.Windows.Forms.Label
$ViewLabel.Text = "View:"
$ViewLabel.Location = New-Object System.Drawing.Point(15, 58)
$ViewLabel.Size = New-Object System.Drawing.Size(38, 20)
$Form.Controls.Add($ViewLabel)

$ViewCombo = New-Object System.Windows.Forms.ComboBox
$ViewCombo.DropDownStyle = "DropDownList"
$ViewCombo.Location = New-Object System.Drawing.Point(53, 55)
$ViewCombo.Size = New-Object System.Drawing.Size(240, 24)
[void]$ViewCombo.Items.AddRange(@("Curated Bloat List", "Installed Store (UWP) Apps", "Installed Desktop Programs"))
$ViewCombo.SelectedIndex = 0
$Form.Controls.Add($ViewCombo)

$PresetLabel = New-Object System.Windows.Forms.Label
$PresetLabel.Text = "Preset:"
$PresetLabel.Location = New-Object System.Drawing.Point(303, 58)
$PresetLabel.Size = New-Object System.Drawing.Size(48, 20)
$Form.Controls.Add($PresetLabel)

$PresetCombo = New-Object System.Windows.Forms.ComboBox
$PresetCombo.DropDownStyle = "DropDownList"
$PresetCombo.Location = New-Object System.Drawing.Point(351, 55)
$PresetCombo.Size = New-Object System.Drawing.Size(150, 24)
[void]$PresetCombo.Items.AddRange(@("Custom", "Safe", "Recommended", "Aggressive"))
$PresetCombo.SelectedIndex = 1
$Form.Controls.Add($PresetCombo)

$SearchLabel = New-Object System.Windows.Forms.Label
$SearchLabel.Text = "Filter:"
$SearchLabel.Location = New-Object System.Drawing.Point(511, 58)
$SearchLabel.Size = New-Object System.Drawing.Size(38, 20)
$Form.Controls.Add($SearchLabel)

$SearchBox = New-Object System.Windows.Forms.TextBox
$SearchBox.Location = New-Object System.Drawing.Point(549, 55)
$SearchBox.Size = New-Object System.Drawing.Size(215, 24)
$SearchBox.Anchor = "Top,Right"
$Form.Controls.Add($SearchBox)

# --- App checklist ---
$AppList = New-Object System.Windows.Forms.CheckedListBox
$AppList.Location = New-Object System.Drawing.Point(15, 84)
$AppList.Size = New-Object System.Drawing.Size(470, 430)
$AppList.CheckOnClick = $true
$AppList.IntegralHeight = $false
$AppList.Anchor = "Top,Bottom,Left,Right"
$Form.Controls.Add($AppList)

# Curated view starts with everything checked (as in the original tool).
foreach ($app in $script:CurrentApps) { $script:Checked[$app.Id] = $true }

# Keep the model in sync when the user ticks boxes. The list only ever shows
# Get-VisibleApps() in order, so the item index maps to that sequence (not to
# $script:CurrentApps directly, which a filter can shorten).
$AppList.Add_ItemCheck({
    param($sender, $e)
    $visible = Get-VisibleApps
    if ($e.Index -ge 0 -and $e.Index -lt $visible.Count) {
        $script:Checked[$visible[$e.Index].Id] = ($e.NewValue -eq [System.Windows.Forms.CheckState]::Checked)
    }
    Update-ListSummary
})

# --- List buttons ---
$SelectAllBtn = New-Object System.Windows.Forms.Button
$SelectAllBtn.Text = "Select All"
$SelectAllBtn.Location = New-Object System.Drawing.Point(15, 522)
$SelectAllBtn.Size = New-Object System.Drawing.Size(100, 26)
$SelectAllBtn.Anchor = "Bottom,Left"
$SelectAllBtn.Add_Click({
    foreach ($it in Get-VisibleApps) { $script:Checked[$it.Id] = $true }
    Update-ListDisplay
})
$Form.Controls.Add($SelectAllBtn)

$SelectNoneBtn = New-Object System.Windows.Forms.Button
$SelectNoneBtn.Text = "Select None"
$SelectNoneBtn.Location = New-Object System.Drawing.Point(120, 522)
$SelectNoneBtn.Size = New-Object System.Drawing.Size(100, 26)
$SelectNoneBtn.Anchor = "Bottom,Left"
$SelectNoneBtn.Add_Click({
    foreach ($it in Get-VisibleApps) { $script:Checked[$it.Id] = $false }
    Update-ListDisplay
})
$Form.Controls.Add($SelectNoneBtn)

$RefreshBtn = New-Object System.Windows.Forms.Button
$RefreshBtn.Text = "Refresh"
$RefreshBtn.Location = New-Object System.Drawing.Point(225, 522)
$RefreshBtn.Size = New-Object System.Drawing.Size(100, 26)
$RefreshBtn.Anchor = "Bottom,Left"
$Form.Controls.Add($RefreshBtn)

$ResultsBtn = New-Object System.Windows.Forms.Button
$ResultsBtn.Text = "View Results"
$ResultsBtn.Location = New-Object System.Drawing.Point(330, 522)
$ResultsBtn.Size = New-Object System.Drawing.Size(100, 26)
$ResultsBtn.Anchor = "Bottom,Left"
$ResultsBtn.Enabled = $false
$ResultsBtn.Add_Click({ Show-Results })
$Form.Controls.Add($ResultsBtn)

$ViewCombo.Add_SelectedIndexChanged({
    $ViewCombo.Enabled = $false; $RefreshBtn.Enabled = $false; $RunBtn.Enabled = $false
    $StatusLabel.Text = "Loading..."
    [System.Windows.Forms.Application]::DoEvents()
    switch ($ViewCombo.SelectedIndex) {
        0 { Load-View -Mode "Curated" }
        1 { Load-View -Mode "InstalledAppx" }
        2 {
            Load-View -Mode "Desktop"
            Write-Log "Desktop program uninstalls may show their own confirmation window - follow any prompts that appear." "Yellow"
            Write-Log "Be careful with shared runtimes (Visual C++ Redistributables, .NET, drivers) - other apps may depend on them." "Yellow"
        }
    }
    $ViewCombo.Enabled = $true; $RefreshBtn.Enabled = $true; $RunBtn.Enabled = $true
})

$PresetCombo.Add_SelectedIndexChanged({
    if ($PresetCombo.SelectedItem -eq "Custom") { return }
    Apply-Preset -Name $PresetCombo.SelectedItem
    Write-Log "Applied preset: $($PresetCombo.SelectedItem)." "Cyan"
})

$SearchBox.Add_TextChanged({
    $script:Filter = $SearchBox.Text.Trim()
    Update-ListDisplay
})

$RefreshBtn.Add_Click({
    $ViewCombo.Enabled = $false; $RefreshBtn.Enabled = $false; $RunBtn.Enabled = $false
    $StatusLabel.Text = "Refreshing..."
    [System.Windows.Forms.Application]::DoEvents()
    switch ($script:ViewMode) {
        "Curated" {
            Write-Log "Refreshing installed status for the curated list..." "Yellow"
            foreach ($app in $script:CurrentApps) {
                $isInstalled = [bool](Get-AppxPackage -AllUsers -Name $app.Id -ErrorAction SilentlyContinue)
                if (-not $isInstalled) {
                    $isInstalled = [bool](Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $app.Id })
                }
                $app.Installed = $isInstalled
            }
            Update-ListDisplay
            $StatusLabel.Text = "Refreshed install status for the curated list."
        }
        "InstalledAppx" {
            Write-Log "Refreshing installed Store apps..." "Yellow"
            Load-View -Mode "InstalledAppx"
            $StatusLabel.Text = "Refreshed. Showing $($script:CurrentApps.Count) installed Store apps."
        }
        "Desktop" {
            Write-Log "Refreshing installed desktop programs..." "Yellow"
            Load-View -Mode "Desktop"
            $StatusLabel.Text = "Refreshed. Showing $($script:CurrentApps.Count) installed desktop programs."
        }
    }
    Write-Log "Refresh complete." "LightGreen"
    $ViewCombo.Enabled = $true; $RefreshBtn.Enabled = $true; $RunBtn.Enabled = $true
})

# --- Options panel ---
$OptionsBox = New-Object System.Windows.Forms.GroupBox
$OptionsBox.Text = "Options"
$OptionsBox.Location = New-Object System.Drawing.Point(500, 55)
$OptionsBox.Size = New-Object System.Drawing.Size(264, 460)
$OptionsBox.Anchor = "Top,Right,Bottom"
$Form.Controls.Add($OptionsBox)

$chkRestore = New-Object System.Windows.Forms.CheckBox
$chkRestore.Text = "Create System Restore Point"
$chkRestore.Location = New-Object System.Drawing.Point(15, 30)
$chkRestore.Size = New-Object System.Drawing.Size(235, 40)
$chkRestore.Checked = $true
$OptionsBox.Controls.Add($chkRestore)

$chkAllUsers = New-Object System.Windows.Forms.CheckBox
$chkAllUsers.Text = "Remove apps for all users (not just this account)"
$chkAllUsers.Location = New-Object System.Drawing.Point(15, 75)
$chkAllUsers.Size = New-Object System.Drawing.Size(235, 40)
$chkAllUsers.Checked = $true
$OptionsBox.Controls.Add($chkAllUsers)

$chkTelemetry = New-Object System.Windows.Forms.CheckBox
$chkTelemetry.Text = "Reduce telemetry (diagnostic data, DiagTrack service, CEIP tasks)"
$chkTelemetry.Location = New-Object System.Drawing.Point(15, 120)
$chkTelemetry.Size = New-Object System.Drawing.Size(235, 50)
$chkTelemetry.Checked = $true
$OptionsBox.Controls.Add($chkTelemetry)

$chkAds = New-Object System.Windows.Forms.CheckBox
$chkAds.Text = "Disable Start menu / lock screen ads and suggestions"
$chkAds.Location = New-Object System.Drawing.Point(15, 175)
$chkAds.Size = New-Object System.Drawing.Size(235, 50)
$chkAds.Checked = $true
$OptionsBox.Controls.Add($chkAds)

$chk3D = New-Object System.Windows.Forms.CheckBox
$chk3D.Text = "Remove '3D Objects' from This PC"
$chk3D.Location = New-Object System.Drawing.Point(15, 230)
$chk3D.Size = New-Object System.Drawing.Size(235, 40)
$chk3D.Checked = $true
$OptionsBox.Controls.Add($chk3D)

$NoteLabel = New-Object System.Windows.Forms.Label
$NoteLabel.Text = "Windows Defender, Windows Update, drivers, and core apps (Store, Calculator, Notepad, Photos, Terminal) are never touched."
$NoteLabel.Location = New-Object System.Drawing.Point(15, 285)
$NoteLabel.Size = New-Object System.Drawing.Size(235, 120)
$NoteLabel.Anchor = "Top,Bottom,Left,Right"
$NoteLabel.ForeColor = [System.Drawing.Color]::DimGray
$OptionsBox.Controls.Add($NoteLabel)

# --- Run / Close buttons ---
$RunBtn = New-Object System.Windows.Forms.Button
$RunBtn.Text = "Run Selected"
$RunBtn.Location = New-Object System.Drawing.Point(500, 522)
$RunBtn.Size = New-Object System.Drawing.Size(130, 32)
$RunBtn.Anchor = "Bottom,Right"
$RunBtn.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$RunBtn.ForeColor = [System.Drawing.Color]::White
$Form.Controls.Add($RunBtn)

$CloseBtn = New-Object System.Windows.Forms.Button
$CloseBtn.Text = "Close"
$CloseBtn.Location = New-Object System.Drawing.Point(640, 522)
$CloseBtn.Size = New-Object System.Drawing.Size(124, 32)
$CloseBtn.Anchor = "Bottom,Right"
$CloseBtn.Add_Click({ $Form.Close() })
$Form.Controls.Add($CloseBtn)

# --- Progress bar ---
$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.Location = New-Object System.Drawing.Point(15, 562)
$ProgressBar.Size = New-Object System.Drawing.Size(749, 18)
$ProgressBar.Anchor = "Bottom,Left,Right"
$Form.Controls.Add($ProgressBar)

# --- Log pane ---
$LogBox = New-Object System.Windows.Forms.RichTextBox
$LogBox.Location = New-Object System.Drawing.Point(15, 588)
$LogBox.Size = New-Object System.Drawing.Size(749, 130)
$LogBox.ReadOnly = $true
$LogBox.BackColor = [System.Drawing.Color]::Black
$LogBox.ForeColor = [System.Drawing.Color]::LightGray
$LogBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$LogBox.Anchor = "Bottom,Left,Right"
$Form.Controls.Add($LogBox)

$StatusLabel = New-Object System.Windows.Forms.Label
$StatusLabel.Text = "Ready. Nothing has been changed yet."
$StatusLabel.Location = New-Object System.Drawing.Point(15, 724)
$StatusLabel.Size = New-Object System.Drawing.Size(749, 20)
$StatusLabel.Anchor = "Bottom,Left,Right"
$Form.Controls.Add($StatusLabel)

# ------------------------------------------------------------------
# RUN LOGIC
# ------------------------------------------------------------------
function Get-RunSummaryText {
    param($SelectedApps)
    $lines = @()
    $lines += "Apps to remove ($($SelectedApps.Count)):"
    if ($SelectedApps.Count -eq 0) {
        $lines += "  (none)"
    } else {
        foreach ($a in $SelectedApps) { $lines += "  - $($a.Display)" }
    }
    $lines += ""
    $lines += "Settings to apply:"
    if ($chkRestore.Checked)   { $lines += "  - Create System Restore Point" }
    if ($chkAllUsers.Checked)  { $lines += "  - Remove apps for all users" }
    if ($chkTelemetry.Checked) { $lines += "  - Reduce telemetry" }
    if ($chkAds.Checked)       { $lines += "  - Disable ads / suggestions" }
    if ($chk3D.Checked)        { $lines += "  - Remove '3D Objects' from This PC" }
    $lines += ""
    $lines += "Continue?"
    return ($lines -join "`r`n")
}

$RunBtn.Add_Click({
    $SelectedApps = @($script:CurrentApps | Where-Object { $script:Checked[$_.Id] })

    # Confirmation summary - nothing is changed until the user accepts.
    $summary = Get-RunSummaryText -SelectedApps $SelectedApps
    $confirm = [System.Windows.Forms.MessageBox]::Show($summary, "Confirm Debloat Run", "OKCancel", "Warning")
    if ($confirm -ne "OK") {
        Write-Log "Run cancelled at the confirmation prompt." "Orange"
        return
    }

    $RunBtn.Enabled = $false
    $CloseBtn.Enabled = $false
    $AppList.Enabled = $false
    $OptionsBox.Enabled = $false
    $ViewCombo.Enabled = $false
    $RefreshBtn.Enabled = $false
    $PresetCombo.Enabled = $false
    $SearchBox.Enabled = $false
    $StatusLabel.Text = "Running..."

    $script:Results = @()
    $TotalSteps = $SelectedApps.Count + 4
    $ProgressBar.Maximum = [Math]::Max($TotalSteps, 1)
    $ProgressBar.Value = 0

    Write-Log "==== Starting debloat run ====" "Cyan"

    # 1. Restore point
    if ($chkRestore.Checked) {
        Write-Log "Creating System Restore Point..." "Yellow"
        try {
            Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description "Pre-Debloat" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
            Write-Log "Restore point created." "LightGreen"
            Add-Result -Name "System Restore Point" -Outcome "Created"
        } catch {
            Write-Log "Could not create restore point (may be throttled to 1/day): $($_.Exception.Message)" "Orange"
            Add-Result -Name "System Restore Point" -Outcome "Failed: $($_.Exception.Message)"
        }
    }
    $ProgressBar.Value++

    # 2. Remove selected apps
    foreach ($app in $SelectedApps) {
        $kind = if ($app.Kind) { $app.Kind } else { "Appx" }

        if ($kind -eq "Desktop") {
            Write-Log "Uninstalling: $($app.Display)" "Yellow"
            try {
                if ($app.IsMSI -and $app.ProductCode) {
                    Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $($app.ProductCode) /qn /norestart" -Wait -ErrorAction Stop
                    Write-Log "Silently uninstalled (MSI): $($app.Display)" "LightGreen"
                    Add-Result -Name $app.Display -Outcome "Uninstalled (MSI)"
                } else {
                    $cmd = if ($app.QuietUninstallString) { $app.QuietUninstallString } else { $app.UninstallString }
                    if ($cmd) {
                        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$cmd`"" -Wait -ErrorAction Stop
                        Write-Log "Ran uninstaller for: $($app.Display) (it may have opened its own window - check for prompts)" "LightGreen"
                        Add-Result -Name $app.Display -Outcome "Uninstaller run"
                    } else {
                        Write-Log "No uninstall command found for: $($app.Display)" "Orange"
                        Add-Result -Name $app.Display -Outcome "No uninstall command"
                    }
                }
            } catch {
                Write-Log "Failed to uninstall $($app.Display): $($_.Exception.Message)" "Orange"
                Add-Result -Name $app.Display -Outcome "Failed: $($_.Exception.Message)"
            }
            $ProgressBar.Value++
            continue
        }

        $removedAny = $false
        $Provisioned = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $app.Id }
        foreach ($p in $Provisioned) {
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop | Out-Null
                $removedAny = $true
            } catch { }
        }
        $params = if ($chkAllUsers.Checked) { @{ AllUsers = $true } } else { @{} }
        $Installed = Get-AppxPackage @params -Name $app.Id -ErrorAction SilentlyContinue
        foreach ($i in $Installed) {
            try {
                Remove-AppxPackage -Package $i.PackageFullName @params -ErrorAction Stop
                $removedAny = $true
            } catch { }
        }
        if ($removedAny) {
            Write-Log "Removed: $($app.Display)" "LightGreen"
            Add-Result -Name $app.Display -Outcome "Removed"
        } else {
            Write-Log "Not installed / already removed: $($app.Display)" "Gray"
            Add-Result -Name $app.Display -Outcome "Not installed"
        }
        $ProgressBar.Value++
    }

    # 3. Telemetry
    if ($chkTelemetry.Checked) {
        Write-Log "Adjusting telemetry settings..." "Yellow"
        try {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 1 -Type DWord -Force -ErrorAction Stop
            Write-Log "Diagnostic data set to Basic." "LightGreen"
            Add-Result -Name "Diagnostic data level" -Outcome "Set to Basic"
        } catch {
            Write-Log "Could not set diagnostic data level." "Orange"
            Add-Result -Name "Diagnostic data level" -Outcome "Failed"
        }

        try {
            Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -Type DWord -Force -ErrorAction Stop
            Write-Log "Disabled tailored experiences." "LightGreen"
            Add-Result -Name "Tailored experiences" -Outcome "Disabled"
        } catch {
            Write-Log "Could not disable tailored experiences." "Orange"
            Add-Result -Name "Tailored experiences" -Outcome "Failed"
        }

        $Tasks = @(
            "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
            "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
            "\Microsoft\Windows\Autochk\Proxy"
            "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
            "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
            "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
        )
        foreach ($t in $Tasks) {
            try {
                Disable-ScheduledTask -TaskPath (Split-Path $t) -TaskName (Split-Path $t -Leaf) -ErrorAction Stop | Out-Null
                Write-Log "Disabled task: $t" "LightGreen"
            } catch {
                Write-Log "Task not found: $t" "Gray"
            }
        }

        try {
            Stop-Service "DiagTrack" -Force -ErrorAction SilentlyContinue
            Set-Service "DiagTrack" -StartupType Disabled -ErrorAction Stop
            Write-Log "Disabled DiagTrack service." "LightGreen"
            Add-Result -Name "DiagTrack service" -Outcome "Disabled"
        } catch {
            Write-Log "Could not disable DiagTrack service." "Orange"
            Add-Result -Name "DiagTrack service" -Outcome "Failed"
        }
    }
    $ProgressBar.Value++

    # 4. Ads / suggestions
    if ($chkAds.Checked) {
        Write-Log "Disabling ads and suggested content..." "Yellow"
        $CDMPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        if (-not (Test-Path $CDMPath)) { New-Item -Path $CDMPath -Force | Out-Null }
        $CDMSettings = @{
            "SubscribedContent-338388Enabled" = 0
            "SubscribedContent-338389Enabled" = 0
            "SubscribedContent-353694Enabled" = 0
            "SubscribedContent-353696Enabled" = 0
            "SilentInstalledAppsEnabled"      = 0
            "SystemPaneSuggestionsEnabled"    = 0
            "PreInstalledAppsEnabled"         = 0
            "OemPreInstalledAppsEnabled"      = 0
        }
        foreach ($key in $CDMSettings.Keys) {
            try {
                Set-ItemProperty -Path $CDMPath -Name $key -Value $CDMSettings[$key] -Type DWord -Force -ErrorAction Stop
            } catch { }
        }
        Write-Log "Content delivery / suggestion keys set." "LightGreen"
        Add-Result -Name "Ads / suggestions" -Outcome "Disabled"

        try {
            $UPEPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement"
            if (-not (Test-Path $UPEPath)) { New-Item -Path $UPEPath -Force | Out-Null }
            Set-ItemProperty -Path $UPEPath -Name "ScoobeSystemSettingEnabled" -Value 0 -Type DWord -Force -ErrorAction Stop
            Write-Log "Disabled Windows welcome experience." "LightGreen"
        } catch {
            Write-Log "Could not disable welcome experience." "Orange"
        }
    }
    $ProgressBar.Value++

    # 5. Misc cleanup
    if ($chk3D.Checked) {
        try {
            $regPaths = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}"
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}"
            )
            foreach ($p in $regPaths) {
                if (Test-Path $p) { Remove-Item -Path $p -Recurse -Force -ErrorAction Stop }
            }
            Write-Log "Removed '3D Objects' from This PC." "LightGreen"
            Add-Result -Name "'3D Objects' entry" -Outcome "Removed"
        } catch {
            Write-Log "Could not remove '3D Objects' entry." "Orange"
            Add-Result -Name "'3D Objects' entry" -Outcome "Failed"
        }
    }
    $ProgressBar.Value = $ProgressBar.Maximum

    Write-Log "==== Done. Log saved to $script:LogFile ====" "Cyan"
    $StatusLabel.Text = "Done. A reboot is recommended for all changes to take effect."

    $RunBtn.Enabled = $true
    $CloseBtn.Enabled = $true
    $AppList.Enabled = $true
    $OptionsBox.Enabled = $true
    $ViewCombo.Enabled = $true
    $RefreshBtn.Enabled = $true
    $PresetCombo.Enabled = $true
    $SearchBox.Enabled = $true
    $ResultsBtn.Enabled = $true

    if ($script:Results.Count -gt 0) { Show-Results }

    $reboot = [System.Windows.Forms.MessageBox]::Show("Debloat finished. Reboot now to apply all changes?", "Debloat Tool", "YesNo", "Question")
    if ($reboot -eq "Yes") { Restart-Computer -Force }
})

# ------------------------------------------------------------------
# STARTUP
# ------------------------------------------------------------------
Update-ListDisplay
Write-Log "Windows 10 Debloat Tool ready. Nothing has been changed yet." "Cyan"

[void]$Form.ShowDialog()
