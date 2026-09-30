; Inno Setup script for the Windows 10 Debloat Tool.
;
; Build (on Windows, with Inno Setup 6 installed):
;     iscc.exe installer\Windows10DebloatTool.iss
;
; The output installer is written to dist\Windows10DebloatTool-Setup.exe.
;
; The tool is a plain PowerShell script, so this just stages the .ps1 files,
; creates elevated Start Menu / desktop shortcuts, and registers an uninstaller.
; It mirrors Install-DebloatTool.ps1 but produces a normal Setup.exe.

#define AppName        "Windows 10 Debloat Tool"
#define AppVersion     "1.1.0"
#define AppPublisher   "hands"
#define AppExeName     "Windows10DebloatTool"

[Setup]
AppId={{8E1B4C0A-2F6D-4A3B-9C7E-5D1A6B2C9F41}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppExeName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename={#AppExeName}-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; The tool edits HKLM and removes Appx packages, so it needs admin.
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64
ArchitecturesAllowed=x64
UninstallDisplayName={#AppName}
UninstallDisplayIcon={sys}\WindowsPowerShell\v1.0\powershell.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Source paths are relative to this .iss file (installer\..\).
Source: "..\Windows10-Debloat-GUI.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Install-DebloatTool.ps1";   DestDir: "{app}"; Flags: ignoreversion
Source: "..\Uninstall-DebloatTool.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md";                 DestDir: "{app}"; Flags: ignoreversion isreadme

[Icons]
; Both shortcuts are flagged run-as-administrator so the tool elevates cleanly.
Name: "{group}\{#AppName}"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Windows10-Debloat-GUI.ps1"""; \
    WorkingDir: "{app}"; IconFilename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
    Comment: "{#AppName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Windows10-Debloat-GUI.ps1"""; \
    WorkingDir: "{app}"; IconFilename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
    Comment: "{#AppName}"; Tasks: desktopicon

[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Windows10-Debloat-GUI.ps1"""; \
    WorkingDir: "{app}"; Description: "{cm:LaunchProgram,{#AppName}}"; \
    Flags: nowait postinstall skipifsilent

[UninstallDelete]
; The log the tool writes next to the script.
Type: files; Name: "{app}\Debloat-Log.txt"

[Code]
// Inno's own shortcuts cannot carry the "run as administrator" bit, so set it
// on the .lnk files after they are created (byte 0x15, mask 0x20).
const
  RunAsAdminOffset = $15;
  RunAsAdminMask   = $20;

procedure SetRunAsAdmin(const LinkPath: String);
var
  Stream: TFileStream;
  Flag: Byte;
begin
  if not FileExists(LinkPath) then
    exit;
  try
    Stream := TFileStream.Create(LinkPath, fmOpenReadWrite);
    try
      Stream.Seek(RunAsAdminOffset, soFromBeginning);
      Stream.ReadBuffer(Flag, 1);
      Flag := Flag or RunAsAdminMask;
      Stream.Seek(RunAsAdminOffset, soFromBeginning);
      Stream.WriteBuffer(Flag, 1);
    finally
      Stream.Free;
    end;
  except
    // A locked or missing shortcut should not fail the install.
  end;
end;

procedure FlagShortcuts();
begin
  SetRunAsAdmin(ExpandConstant('{group}\') + '{#AppName}.lnk');
  if WizardIsTaskSelected('desktopicon') then
    SetRunAsAdmin(ExpandConstant('{autodesktop}\') + '{#AppName}.lnk');
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    FlagShortcuts();
end;
