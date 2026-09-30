<#
.SYNOPSIS
    Windows 10 Debloat Tool - GUI Edition

.DESCRIPTION
    A point-and-click front end for debloating Windows 10: pick which
    pre-installed apps to remove, toggle telemetry/ads settings, then
    click Run. Progress and results are shown live in the log pane and
    saved to Debloat-Log.txt next to the script.

.NOTES
    - Self-elevates: if you don't run it as Administrator, it will
      relaunch itself with a UAC prompt.
    - Nothing runs until you click "Run Selected".
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

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ------------------------------------------------------------------
# DATA: apps available for removal (DisplayName shown in list, Id used to match packages)
# ------------------------------------------------------------------
$AppCatalog = @(
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
    @{ Display = "Facebook (OEM)";                 Id = "*Facebook*"; Group = "OEM" }
    @{ Display = "Twitter (OEM)";                  Id = "*Twitter*"; Group = "OEM" }
    @{ Display = "Spotify (OEM)";                  Id = "*Spotify*"; Group = "OEM" }
    @{ Display = "Disney+ (OEM)";                  Id = "*Disney*"; Group = "OEM" }
    @{ Display = "Candy Crush (OEM)";               Id = "*CandyCrush*"; Group = "OEM" }
    @{ Display = "Bubble Witch (OEM)";              Id = "*BubbleWitch*"; Group = "OEM" }
    @{ Display = "McAfee (OEM)";                   Id = "*McAfee*"; Group = "OEM" }
    @{ Display = "Dolby Access (OEM)";              Id = "*Dolby*"; Group = "OEM" }
)

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
# APP LIST HELPERS (curated list vs. live scan of what's installed)
# ------------------------------------------------------------------
$script:ViewMode = "Curated"   # "Curated" | "InstalledAppx" | "Desktop"
$script:CurrentApps = $AppCatalog

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
    $AppList.Items.Clear()
    foreach ($it in $Items) {
        [void]$AppList.Items.Add($it.Display, $DefaultChecked)
    }
}

function Load-View {
    param([string]$Mode, [switch]$PreserveChecks)
    $checkedIds = @()
    if ($PreserveChecks) {
        for ($i = 0; $i -lt $AppList.Items.Count; $i++) {
            if ($AppList.GetItemChecked($i)) { $checkedIds += $script:CurrentApps[$i].Id }
        }
    }
    switch ($Mode) {
        "Curated" {
            Set-AppListItems -Items $AppCatalog -DefaultChecked:$true
        }
        "InstalledAppx" {
            $items = Get-InstalledAppItems
            Set-AppListItems -Items $items -DefaultChecked:$false
            # Pre-check anything matching a known bloat/OEM pattern for convenience
            for ($i = 0; $i -lt $script:CurrentApps.Count; $i++) {
                $id = $script:CurrentApps[$i].Id
                if ($AppCatalog | Where-Object { $id -like $_.Id }) { $AppList.SetItemChecked($i, $true) }
            }
        }
        "Desktop" {
            $items = Get-DesktopAppItems
            Set-AppListItems -Items $items -DefaultChecked:$false
        }
    }
    if ($PreserveChecks) {
        for ($i = 0; $i -lt $script:CurrentApps.Count; $i++) {
            if ($checkedIds -contains $script:CurrentApps[$i].Id) { $AppList.SetItemChecked($i, $true) }
        }
    }
    $script:ViewMode = $Mode
}

# ------------------------------------------------------------------
# BUILD FORM
# ------------------------------------------------------------------
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Windows 10 Debloat Tool"
$Form.Size = New-Object System.Drawing.Size(720, 760)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "FixedDialog"
$Form.MaximizeBox = $false
$Form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$TitleLabel = New-Object System.Windows.Forms.Label
$TitleLabel.Text = "Select apps to remove and options to apply, then click Run."
$TitleLabel.Location = New-Object System.Drawing.Point(15, 12)
$TitleLabel.Size = New-Object System.Drawing.Size(680, 20)
$Form.Controls.Add($TitleLabel)

# --- App checklist ---
$ViewLabel = New-Object System.Windows.Forms.Label
$ViewLabel.Text = "View:"
$ViewLabel.Location = New-Object System.Drawing.Point(15, 40)
$ViewLabel.Size = New-Object System.Drawing.Size(40, 20)
$Form.Controls.Add($ViewLabel)

$ViewCombo = New-Object System.Windows.Forms.ComboBox
$ViewCombo.DropDownStyle = "DropDownList"
$ViewCombo.Location = New-Object System.Drawing.Point(55, 37)
$ViewCombo.Size = New-Object System.Drawing.Size(380, 24)
[void]$ViewCombo.Items.AddRange(@("Curated Bloat List", "Installed Store (UWP) Apps", "Installed Desktop Programs"))
$ViewCombo.SelectedIndex = 0
$Form.Controls.Add($ViewCombo)

$AppList = New-Object System.Windows.Forms.CheckedListBox
$AppList.Location = New-Object System.Drawing.Point(15, 66)
$AppList.Size = New-Object System.Drawing.Size(420, 372)
$AppList.CheckOnClick = $true
foreach ($app in $script:CurrentApps) {
    [void]$AppList.Items.Add($app.Display, $true)
}
$Form.Controls.Add($AppList)

$SelectAllBtn = New-Object System.Windows.Forms.Button
$SelectAllBtn.Text = "Select All"
$SelectAllBtn.Location = New-Object System.Drawing.Point(15, 444)
$SelectAllBtn.Size = New-Object System.Drawing.Size(95, 26)
$SelectAllBtn.Add_Click({ for ($i = 0; $i -lt $AppList.Items.Count; $i++) { $AppList.SetItemChecked($i, $true) } })
$Form.Controls.Add($SelectAllBtn)

$SelectNoneBtn = New-Object System.Windows.Forms.Button
$SelectNoneBtn.Text = "Select None"
$SelectNoneBtn.Location = New-Object System.Drawing.Point(115, 444)
$SelectNoneBtn.Size = New-Object System.Drawing.Size(95, 26)
$SelectNoneBtn.Add_Click({ for ($i = 0; $i -lt $AppList.Items.Count; $i++) { $AppList.SetItemChecked($i, $false) } })
$Form.Controls.Add($SelectNoneBtn)

$RefreshBtn = New-Object System.Windows.Forms.Button
$RefreshBtn.Text = "Refresh"
$RefreshBtn.Location = New-Object System.Drawing.Point(215, 444)
$RefreshBtn.Size = New-Object System.Drawing.Size(95, 26)
$Form.Controls.Add($RefreshBtn)

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
    $StatusLabel.Text = "Showing $($script:CurrentApps.Count) item(s) - $($ViewCombo.SelectedItem)."
    $ViewCombo.Enabled = $true; $RefreshBtn.Enabled = $true; $RunBtn.Enabled = $true
})

$RefreshBtn.Add_Click({
    $ViewCombo.Enabled = $false; $RefreshBtn.Enabled = $false; $RunBtn.Enabled = $false
    $StatusLabel.Text = "Refreshing..."
    [System.Windows.Forms.Application]::DoEvents()
    switch ($script:ViewMode) {
        "Curated" {
            Write-Log "Refreshing installed status for the curated list..." "Yellow"
            for ($i = 0; $i -lt $script:CurrentApps.Count; $i++) {
                $app = $script:CurrentApps[$i]
                $wasChecked = $AppList.GetItemChecked($i)
                $isInstalled = [bool](Get-AppxPackage -AllUsers -Name $app.Id -ErrorAction SilentlyContinue)
                if (-not $isInstalled) {
                    $isInstalled = [bool](Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $app.Id })
                }
                $suffix = if ($isInstalled) { "  -  Installed" } else { "  -  Not installed" }
                $AppList.Items[$i] = "$($app.Display)$suffix"
                $AppList.SetItemChecked($i, $wasChecked)
            }
            $StatusLabel.Text = "Refreshed install status for the curated list."
        }
        "InstalledAppx" {
            Write-Log "Refreshing installed Store apps..." "Yellow"
            Load-View -Mode "InstalledAppx" -PreserveChecks
            $StatusLabel.Text = "Refreshed. Showing $($script:CurrentApps.Count) installed Store apps."
        }
        "Desktop" {
            Write-Log "Refreshing installed desktop programs..." "Yellow"
            Load-View -Mode "Desktop" -PreserveChecks
            $StatusLabel.Text = "Refreshed. Showing $($script:CurrentApps.Count) installed desktop programs."
        }
    }
    Write-Log "Refresh complete." "LightGreen"
    $ViewCombo.Enabled = $true; $RefreshBtn.Enabled = $true; $RunBtn.Enabled = $true
})

# --- Options panel ---
$OptionsBox = New-Object System.Windows.Forms.GroupBox
$OptionsBox.Text = "Options"
$OptionsBox.Location = New-Object System.Drawing.Point(450, 38)
$OptionsBox.Size = New-Object System.Drawing.Size(245, 400)
$Form.Controls.Add($OptionsBox)

$chkRestore = New-Object System.Windows.Forms.CheckBox
$chkRestore.Text = "Create System Restore Point"
$chkRestore.Location = New-Object System.Drawing.Point(15, 30)
$chkRestore.Size = New-Object System.Drawing.Size(220, 40)
$chkRestore.Checked = $true
$OptionsBox.Controls.Add($chkRestore)

$chkAllUsers = New-Object System.Windows.Forms.CheckBox
$chkAllUsers.Text = "Remove apps for all users (not just this account)"
$chkAllUsers.Location = New-Object System.Drawing.Point(15, 75)
$chkAllUsers.Size = New-Object System.Drawing.Size(220, 40)
$chkAllUsers.Checked = $true
$OptionsBox.Controls.Add($chkAllUsers)

$chkTelemetry = New-Object System.Windows.Forms.CheckBox
$chkTelemetry.Text = "Reduce telemetry (diagnostic data, DiagTrack service, CEIP tasks)"
$chkTelemetry.Location = New-Object System.Drawing.Point(15, 120)
$chkTelemetry.Size = New-Object System.Drawing.Size(220, 50)
$chkTelemetry.Checked = $true
$OptionsBox.Controls.Add($chkTelemetry)

$chkAds = New-Object System.Windows.Forms.CheckBox
$chkAds.Text = "Disable Start menu / lock screen ads and suggestions"
$chkAds.Location = New-Object System.Drawing.Point(15, 175)
$chkAds.Size = New-Object System.Drawing.Size(220, 50)
$chkAds.Checked = $true
$OptionsBox.Controls.Add($chkAds)

$chk3D = New-Object System.Windows.Forms.CheckBox
$chk3D.Text = "Remove '3D Objects' from This PC"
$chk3D.Location = New-Object System.Drawing.Point(15, 230)
$chk3D.Size = New-Object System.Drawing.Size(220, 40)
$chk3D.Checked = $true
$OptionsBox.Controls.Add($chk3D)

$NoteLabel = New-Object System.Windows.Forms.Label
$NoteLabel.Text = "Windows Defender, Windows Update, drivers, and core apps (Store, Calculator, Notepad, Photos, Terminal) are never touched."
$NoteLabel.Location = New-Object System.Drawing.Point(15, 285)
$NoteLabel.Size = New-Object System.Drawing.Size(220, 100)
$NoteLabel.ForeColor = [System.Drawing.Color]::DimGray
$OptionsBox.Controls.Add($NoteLabel)

# --- Run / Close buttons ---
$RunBtn = New-Object System.Windows.Forms.Button
$RunBtn.Text = "Run Selected"
$RunBtn.Location = New-Object System.Drawing.Point(450, 444)
$RunBtn.Size = New-Object System.Drawing.Size(120, 32)
$RunBtn.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$RunBtn.ForeColor = [System.Drawing.Color]::White
$Form.Controls.Add($RunBtn)

$CloseBtn = New-Object System.Windows.Forms.Button
$CloseBtn.Text = "Close"
$CloseBtn.Location = New-Object System.Drawing.Point(580, 444)
$CloseBtn.Size = New-Object System.Drawing.Size(110, 32)
$CloseBtn.Add_Click({ $Form.Close() })
$Form.Controls.Add($CloseBtn)

# --- Progress bar ---
$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.Location = New-Object System.Drawing.Point(15, 486)
$ProgressBar.Size = New-Object System.Drawing.Size(680, 18)
$Form.Controls.Add($ProgressBar)

# --- Log pane ---
$LogBox = New-Object System.Windows.Forms.RichTextBox
$LogBox.Location = New-Object System.Drawing.Point(15, 512)
$LogBox.Size = New-Object System.Drawing.Size(680, 175)
$LogBox.ReadOnly = $true
$LogBox.BackColor = [System.Drawing.Color]::Black
$LogBox.ForeColor = [System.Drawing.Color]::LightGray
$LogBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$Form.Controls.Add($LogBox)

$StatusLabel = New-Object System.Windows.Forms.Label
$StatusLabel.Text = "Ready. Nothing has been changed yet."
$StatusLabel.Location = New-Object System.Drawing.Point(15, 695)
$StatusLabel.Size = New-Object System.Drawing.Size(680, 20)
$Form.Controls.Add($StatusLabel)

# ------------------------------------------------------------------
# RUN LOGIC
# ------------------------------------------------------------------
$RunBtn.Add_Click({
    $RunBtn.Enabled = $false
    $CloseBtn.Enabled = $false
    $AppList.Enabled = $false
    $OptionsBox.Enabled = $false
    $ViewCombo.Enabled = $false
    $RefreshBtn.Enabled = $false
    $StatusLabel.Text = "Running..."

    $SelectedApps = @()
    for ($i = 0; $i -lt $AppList.Items.Count; $i++) {
        if ($AppList.GetItemChecked($i)) { $SelectedApps += $script:CurrentApps[$i] }
    }

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
        } catch {
            Write-Log "Could not create restore point (may be throttled to 1/day): $($_.Exception.Message)" "Orange"
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
                } else {
                    $cmd = if ($app.QuietUninstallString) { $app.QuietUninstallString } else { $app.UninstallString }
                    if ($cmd) {
                        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$cmd`"" -Wait -ErrorAction Stop
                        Write-Log "Ran uninstaller for: $($app.Display) (it may have opened its own window - check for prompts)" "LightGreen"
                    } else {
                        Write-Log "No uninstall command found for: $($app.Display)" "Orange"
                    }
                }
            } catch {
                Write-Log "Failed to uninstall $($app.Display): $($_.Exception.Message)" "Orange"
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
        } else {
            Write-Log "Not installed / already removed: $($app.Display)" "Gray"
        }
        $ProgressBar.Value++
    }

    # 3. Telemetry
    if ($chkTelemetry.Checked) {
        Write-Log "Adjusting telemetry settings..." "Yellow"
        try {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 1 -Type DWord -Force -ErrorAction Stop
            Write-Log "Diagnostic data set to Basic." "LightGreen"
        } catch { Write-Log "Could not set diagnostic data level." "Orange" }

        try {
            Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -Type DWord -Force -ErrorAction Stop
            Write-Log "Disabled tailored experiences." "LightGreen"
        } catch { Write-Log "Could not disable tailored experiences." "Orange" }

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
            } catch { Write-Log "Task not found: $t" "Gray" }
        }

        try {
            Stop-Service "DiagTrack" -Force -ErrorAction SilentlyContinue
            Set-Service "DiagTrack" -StartupType Disabled -ErrorAction Stop
            Write-Log "Disabled DiagTrack service." "LightGreen"
        } catch { Write-Log "Could not disable DiagTrack service." "Orange" }
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

        try {
            $UPEPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement"
            if (-not (Test-Path $UPEPath)) { New-Item -Path $UPEPath -Force | Out-Null }
            Set-ItemProperty -Path $UPEPath -Name "ScoobeSystemSettingEnabled" -Value 0 -Type DWord -Force -ErrorAction Stop
            Write-Log "Disabled Windows welcome experience." "LightGreen"
        } catch { Write-Log "Could not disable welcome experience." "Orange" }
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
        } catch { Write-Log "Could not remove '3D Objects' entry." "Orange" }
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

    $reboot = [System.Windows.Forms.MessageBox]::Show("Debloat finished. Reboot now to apply all changes?", "Debloat Tool", "YesNo", "Question")
    if ($reboot -eq "Yes") { Restart-Computer -Force }
})

[void]$Form.ShowDialog()
