# Windows 10 Debloat Tool

A point-and-click PowerShell tool for removing pre-installed Windows 10 apps and
turning off telemetry / ad settings. No build step and no third-party runtime —
it is a single PowerShell script.

## Files

| File | Purpose |
| --- | --- |
| `Windows10-Debloat-GUI.ps1` | The tool itself (WinForms GUI). |
| `Install-DebloatTool.ps1` | Installs the tool to Program Files, adds shortcuts and an Add/Remove Programs entry. |
| `Uninstall-DebloatTool.ps1` | Removes the files, shortcuts and registry entry. |

## Install

Right-click `Install-DebloatTool.ps1` → **Run with PowerShell**, or:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Install-DebloatTool.ps1
```

This copies the tool to `%ProgramFiles%\Windows10DebloatTool`, creates a Start
Menu shortcut (and a desktop shortcut unless `-NoDesktopShortcut` is passed),
and registers the tool in **Settings → Apps → Installed apps**. The shortcuts are
flagged to run as administrator.

Optional parameters:

```powershell
.\Install-DebloatTool.ps1 -InstallDir "D:\Tools\Debloat"   # custom location
.\Install-DebloatTool.ps1 -NoDesktopShortcut               # Start Menu only
.\Install-DebloatTool.ps1 -Quiet                           # no closing dialog
```

## Run without installing

Right-click `Windows10-Debloat-GUI.ps1` → **Run with PowerShell**, or:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows10-Debloat-GUI.ps1
```

The script self-elevates, so expect a UAC prompt.

## Using the tool

1. Pick a **View**: the curated bloat list, a live scan of installed Store (UWP)
   apps, or installed desktop (Win32) programs.
2. Choose a **Preset** — `Safe`, `Recommended` or `Aggressive` — or tick items
   manually. Use the **Filter** box to narrow a long list.
3. Choose the **Options** to apply (restore point, all-users removal, telemetry,
   ads, 3D Objects).
4. Click **Run Selected**. A confirmation dialog lists exactly what will change
   before anything happens.
5. Review per-item outcomes with **View Results**; the full log is written to
   `Debloat-Log.txt` next to the script.

The app list is populated for Windows 10. On Windows 11 the extra Windows 11-only
packages (Widgets runtime, Copilot, etc.) are appended automatically.

## Uninstall

Use **Settings → Apps → Installed apps**, or run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "$env:ProgramFiles\Windows10DebloatTool\Uninstall-DebloatTool.ps1"
```

Add `-KeepLog` to copy `Debloat-Log.txt` to the desktop before the install folder
is deleted.

> Uninstalling removes the tool only. Apps and settings it changed are **not**
> reverted — use the System Restore Point it created, or reinstall the apps.

## Safety notes

- Nothing runs until you click **Run Selected** and accept the confirmation.
- Create System Restore Point is on by default (Windows throttles restore points
  to roughly one per day).
- Windows Defender, Windows Update, drivers, and core apps (Store, Calculator,
  Notepad, Photos, Terminal) are never touched.
- Be careful removing shared runtimes (Visual C++ Redistributables, .NET,
  drivers) from the desktop programs view — other apps may depend on them.
